require "test_helper"

class PurchaseTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @channel = channels(:acme_fair)
  end

  def build_purchase(currency: "EUR", fx_rate: nil)
    purchase = @account.purchases.create!(channel: @channel, title: "Test", currency: currency, fx_rate: fx_rate)
    purchase
  end

  test "confirm! requires at least one active line" do
    purchase = build_purchase

    assert_raises(ActiveRecord::RecordInvalid) { purchase.confirm! }
    assert_equal "draft", purchase.reload.status
  end

  test "confirm! moves to ordered and generates pending_arrival items, one per unit" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "Bolt", kind: "single", intent: "sell", quantity: 3, unit_price_cents: 100)

    purchase.confirm!

    assert_equal "ordered", purchase.status
    assert_equal 3, purchase.inventory_items.count
    assert purchase.inventory_items.all? { |item| item.status == "pending_arrival" }
  end

  test "confirm! sums item costs to exactly the landed cost in base currency, no rounding drift" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 3, unit_price_cents: 333)
    purchase.purchase_lines.create!(description: "B", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 1)
    purchase.purchase_charges.create!(kind: "shipping", amount_cents: 500)

    purchase.confirm!
    purchase.reload

    # subtotal = 3*333 + 1*1 = 1000; + 500 shipping = 1500; same-currency fx_rate 1 -> base 1500
    assert_equal 1500, purchase.total_base_cents
    assert_equal 1500, purchase.inventory_items.sum(:cost_base_cents)
  end

  test "confirm! allocates a line's landed cost equally across its items, remainder to lowest id" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 3, unit_price_cents: 100)

    purchase.confirm!

    costs = purchase.inventory_items.order(:id).pluck(:cost_base_cents)
    assert_equal 300, costs.sum
    assert_equal [ 100, 100, 100 ], costs
  end

  test "a bulk_lot line creates exactly one item with the line's full quantity" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "Bulk", kind: "bulk_lot", intent: "sell", quantity: 500, unit_price_cents: 1)

    purchase.confirm!

    assert_equal 1, purchase.inventory_items.count
    assert_equal 500, purchase.inventory_items.first.quantity
    assert_equal 500, purchase.inventory_items.first.cost_base_cents
  end

  test "confirm! only applies to a draft purchase" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)
    purchase.confirm!

    assert_raises(ArgumentError) { purchase.confirm! }
  end

  test "confirm_received! moves straight to received with in_stock items" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)

    purchase.confirm_received!

    assert_equal "received", purchase.status
    assert purchase.inventory_items.all? { |item| item.status == "in_stock" }
  end

  test "receive! transitions the already-generated items from pending_arrival to in_stock" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)
    purchase.confirm!

    purchase.receive!

    assert_equal "received", purchase.status
    assert purchase.inventory_items.reload.all? { |item| item.status == "in_stock" }
  end

  test "cancel! voids the pending items and logs the transition" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)
    purchase.confirm!

    purchase.cancel!(reason: "changed my mind")

    assert_equal "cancelled", purchase.status
    assert purchase.inventory_items.reload.all? { |item| item.status == "voided" }

    transition = purchase.state_transitions.order(:occurred_at).last
    assert_equal "cancel", transition.event
    assert_equal "ordered", transition.from_state
    assert_equal "cancelled", transition.to_state
    assert_equal "changed my mind", transition.reason
  end

  test "requires a manually-set fx_rate to confirm a foreign-currency purchase" do
    purchase = build_purchase(currency: "USD")
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)

    assert_raises(ActiveRecord::RecordInvalid) { purchase.confirm! }

    purchase.update!(fx_rate: "0.9")
    purchase.confirm!
    assert_equal "ordered", purchase.status
  end

  test "converts a foreign-currency total to base cents with the given fx_rate" do
    purchase = build_purchase(currency: "USD", fx_rate: "0.9")
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 1000)

    purchase.confirm!

    assert_equal 900, purchase.reload.total_base_cents
  end

  test "only a draft purchase can be destroyed" do
    purchase = build_purchase
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)
    purchase.confirm!

    assert_not purchase.destroy
    assert Purchase.exists?(purchase.id)
  end
end
