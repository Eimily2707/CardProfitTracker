require "test_helper"

class SaleLineTest < ActiveSupport::TestCase
  setup do
    @sale = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
  end

  test "quantity must be greater than zero" do
    line = @sale.sale_lines.new(description: "A", quantity: 0, unit_price_cents: 100)
    assert_not line.valid?
  end

  test "unit_price_cents cannot be negative" do
    line = @sale.sale_lines.new(description: "A", unit_price_cents: -100)
    assert_not line.valid?
  end

  test "unit_price_base_cents and profit_base_cents are nil before the sale is confirmed (no fx_rate/cost snapshot yet)" do
    line = @sale.sale_lines.create!(description: "A", unit_price_cents: 1000)

    assert_nil line.unit_price_base_cents
    assert_nil line.profit_base_cents
  end

  test "profit_base_cents reflects the order's fx_rate, allocated charges, and cost snapshot once confirmed" do
    item = accounts(:acme).inventory_items.create!(
      kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:acme)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )
    line = @sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)
    @sale.sale_charges.create!(kind: "shipping_charged", amount_cents: 200)
    @sale.confirm_payment!

    line.reload
    assert_equal 1000, line.unit_price_base_cents
    assert_equal 200, line.allocated_net_charges_base_cents
    assert_equal 500, line.cost_base_cents_snapshot
    assert_equal 700, line.profit_base_cents
  end
end
