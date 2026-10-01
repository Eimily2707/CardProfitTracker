require "test_helper"

# Full lifecycle e2e (Tranche 6): a manual purchase confirmed in-person
# (spec US-2.1 confirm_received), the resulting InventoryItem sold through
# a marketplace order (spec US-5.1 confirm_payment), credited, and the
# realized profit read back out of Profits::CalculatorService (spec §7.4).
# Exercises the same chain of service objects Tranches 3-5 each covered in
# isolation, but end to end and through a single account's books.
class PurchaseToProfitTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
  end

  test "a purchase flows through inventory into a credited sale and shows up as realized profit" do
    purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Fiera di primavera", currency: "EUR")
    purchase.purchase_lines.create!(
      description: "Black Lotus", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 10_000
    )

    purchase.confirm_received!
    assert_equal "received", purchase.status

    item = purchase.inventory_items.sole
    assert_equal "in_stock", item.status
    assert_equal 10_000, item.cost_base_cents

    sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 15_000)

    sale.confirm_payment!
    assert_equal "paid", sale.status
    assert_equal "sold", item.reload.status
    assert_equal 5_000, sale.profit_base_cents

    sale.ship!
    sale.deliver!
    sale.mark_credited!
    assert_not_nil sale.credited_at

    calculator = Profits::CalculatorService.new(@account)
    assert_equal 5_000, calculator.realized_profit_base_cents
    assert_equal 10_000, calculator.cogs_base_cents
    assert_equal 50.0, calculator.roi_percent
    assert_equal 0, calculator.invested_capital_base_cents

    audit_events = purchase.versions.map(&:event) + sale.versions.map(&:event)
    assert_includes audit_events, "create"
    assert_includes audit_events, "update"
  end
end
