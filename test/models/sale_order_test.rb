require "test_helper"

class SaleOrderTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @channel = channels(:acme_fair)
  end

  def build_item(cost_cents: 500)
    @account.inventory_items.create!(
      kind: "single", name: "Teferi, Time Raveler", intent: "sell", status: "in_stock",
      cost_source: "manual", acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: cost_cents, cost_base_cents: cost_cents
    )
  end

  def build_sale(currency: "EUR", fx_rate: nil)
    @account.sale_orders.create!(channel: @channel, currency: currency, fx_rate: fx_rate)
  end

  test "confirm_payment! requires at least one active line" do
    sale = build_sale

    assert_raises(ActiveRecord::RecordInvalid) { sale.confirm_payment! }
    assert_equal "draft", sale.reload.status
  end

  test "submit! reserves the matched inventory item without selling it" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)

    sale.submit!

    assert_equal "awaiting_payment", sale.status
    assert_equal "reserved", item.reload.status
  end

  test "confirm_payment! sells the item, snapshots its cost, and computes profit" do
    sale = build_sale
    item = build_item(cost_cents: 500)
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)

    sale.confirm_payment!
    sale.reload

    assert_equal "paid", sale.status
    assert_equal "sold", item.reload.status
    assert_equal 1500, sale.items_subtotal_cents
    assert_equal 1500, sale.net_proceeds_cents
    assert_equal 1500, sale.net_proceeds_base_cents # same-currency, fx_rate 1
    assert_equal 500, sale.cogs_base_cents
    assert_equal 1000, sale.profit_base_cents
    assert_equal 500, sale.sale_lines.first.cost_base_cents_snapshot
  end

  test "confirm_payment! nets shipping income against fee expenses" do
    sale = build_sale
    item = build_item(cost_cents: 500)
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)
    sale.sale_charges.create!(kind: "shipping_charged", amount_cents: 300)
    sale.sale_charges.create!(kind: "platform_fee", amount_cents: 100)

    sale.confirm_payment!
    sale.reload

    assert_equal 1000, sale.items_subtotal_cents
    assert_equal 300, sale.income_total_cents
    assert_equal 100, sale.expense_total_cents
    assert_equal 1200, sale.net_proceeds_cents
    assert_equal 700, sale.profit_base_cents # 1200 - 500 cogs
  end

  test "submit! can go straight from draft, skipping awaiting_payment" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)

    sale.confirm_payment!

    assert_equal "paid", sale.status
  end

  test "ship! then deliver! advance a paid order" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)
    sale.confirm_payment!

    sale.ship!
    assert_equal "shipped", sale.status

    sale.deliver!
    assert_equal "delivered", sale.status
  end

  test "cancel! releases sold items back to in_stock" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)
    sale.confirm_payment!

    sale.cancel!(reason: "buyer backed out")

    assert_equal "cancelled", sale.status
    assert_equal "in_stock", item.reload.status

    transition = sale.state_transitions.order(:occurred_at).last
    assert_equal "cancel", transition.event
    assert_equal "buyer backed out", transition.reason
  end

  test "requires a manually-set fx_rate to confirm a foreign-currency sale" do
    sale = build_sale(currency: "USD")
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)

    assert_raises(ActiveRecord::RecordInvalid) { sale.confirm_payment! }

    sale.update!(fx_rate: "0.9")
    sale.confirm_payment!
    assert_equal "paid", sale.status
  end

  test "an item cannot be attached to two active sale lines" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)

    other_sale = build_sale
    other_line = other_sale.sale_lines.new(inventory_item: item, description: item.name, unit_price_cents: 1000)

    assert_not other_line.valid?
  end

  test "only a draft sale order can be destroyed" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)
    sale.confirm_payment!

    assert_not sale.destroy
    assert SaleOrder.exists?(sale.id)
  end

  test "apply_external_state! logs every external state even when the local status doesn't move" do
    sale = build_sale

    sale.apply_external_state!("pending")

    assert_equal "draft", sale.reload.status
    assert_equal "pending", sale.external_state
    transition = sale.state_transitions.order(:occurred_at).last
    assert_equal "external_sync", transition.event
    assert_equal "draft", transition.from_state
    assert_equal "draft", transition.to_state
  end

  test "apply_external_state! catches up through several local statuses at once" do
    sale = build_sale
    item = build_item
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1000)

    sale.apply_external_state!("arrived")

    assert_equal "delivered", sale.reload.status
    assert_equal "sold", item.reload.status
  end

  test "apply_external_state! flags an unsupported external state for review instead of guessing" do
    sale = build_sale

    sale.apply_external_state!("lost")

    assert_equal "draft", sale.reload.status
    assert sale.review_required?
    assert_includes sale.review_reasons, "external_state_lost"
  end
end
