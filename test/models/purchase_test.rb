require "test_helper"

class PurchaseTest < ActiveSupport::TestCase
  setup do
    @purchase = purchases(:lorcana_box)
  end

  test "valid with required attributes" do
    purchase = Purchase.new(name: "Test Box", currency: "EUR")
    assert purchase.valid?
  end

  test "invalid without a name" do
    purchase = Purchase.new(currency: "EUR")
    assert_not purchase.valid?
    assert_includes purchase.errors[:name], "can't be blank"
  end

  test "invalid without a currency" do
    purchase = Purchase.new(name: "Test Box", currency: nil)
    assert_not purchase.valid?
    assert_includes purchase.errors[:currency], "can't be blank"
  end

  test "rejects negative cents amounts" do
    purchase = Purchase.new(name: "Test Box", currency: "EUR", total_price_cents: -100)
    assert_not purchase.valid?
    assert_includes purchase.errors[:total_price_cents], "must be greater than or equal to 0"
  end

  test "allows nil cents amounts" do
    purchase = Purchase.new(name: "Test Box", currency: "EUR")
    assert purchase.valid?
  end

  test "enforces uniqueness of cardtrader_order_id" do
    duplicate = Purchase.new(name: "Duplicate", currency: "EUR", cardtrader_order_id: @purchase.cardtrader_order_id)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cardtrader_order_id], "has already been taken"
  end

  test "allows several purchases with a nil cardtrader_order_id" do
    a = Purchase.new(name: "A", currency: "EUR")
    b = Purchase.new(name: "B", currency: "EUR")
    assert a.valid?
    assert b.valid?
  end

  test "has_many inventory_items" do
    assert_includes @purchase.inventory_items, inventory_items(:elsa_foil)
    assert_includes @purchase.inventory_items, inventory_items(:mickey_common)
  end

  test "destroying a purchase nullifies its inventory items instead of destroying them" do
    item = inventory_items(:elsa_foil)

    assert_no_difference("InventoryItem.count") do
      @purchase.destroy
    end

    assert_nil item.reload.purchase_id
  end

  test "allocated_cost_cents sums the allocated cost of its inventory items" do
    assert_equal 4650, @purchase.allocated_cost_cents
  end

  test "remaining_to_allocate_cents subtracts allocated cost from price plus shipping" do
    assert_equal 10850, @purchase.remaining_to_allocate_cents
  end

  test "total_spent_cents sums price, shipping and tax" do
    assert_equal 15500, @purchase.total_spent_cents
  end

  test "KPI totals are zero for a purchase with no inventory items yet" do
    purchase = purchases(:single_charizard)
    purchase.inventory_items.destroy_all

    assert_equal 0, purchase.allocated_cost_cents
    assert_equal purchase.total_price_cents + purchase.shipping_cost_cents, purchase.remaining_to_allocate_cents
  end
end
