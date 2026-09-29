require "test_helper"

class PurchaseLineTest < ActiveSupport::TestCase
  setup do
    @purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
  end

  test "computes line_total_cents from unit_price_cents and quantity" do
    line = @purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 3, unit_price_cents: 250)

    assert_equal 750, line.line_total_cents
  end

  test "quantity must be greater than zero" do
    line = @purchase.purchase_lines.new(description: "A", kind: "single", intent: "sell", quantity: 0, unit_price_cents: 100)

    assert_not line.valid?
  end

  test "snapshots description and expansion_name from the blueprint on create" do
    blueprint = ct_blueprints(:teferi)
    line = @purchase.purchase_lines.create!(ct_blueprint: blueprint, kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)

    assert_equal blueprint.name, line.description
    assert_equal blueprint.ct_expansion.name, line.expansion_name
  end

  test "item_count is the line quantity, except for bulk_lot which is always one item" do
    single = @purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 5, unit_price_cents: 100)
    bulk = @purchase.purchase_lines.create!(description: "B", kind: "bulk_lot", intent: "sell", quantity: 500, unit_price_cents: 1)

    assert_equal 5, single.item_count
    assert_equal 1, bulk.item_count
  end
end
