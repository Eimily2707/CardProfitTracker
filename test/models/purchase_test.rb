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

  test "defaults to the crack_and_sell intent" do
    assert_equal "crack_and_sell", Purchase.new.intent_type
  end

  test "saving with keep_sealed auto-creates a sealed InventoryItem for the whole box" do
    purchase = Purchase.create!(
      name: "Booster Box Lorcana", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 15000, shipping_cost_cents: 500
    )

    item = purchase.sealed_inventory_item
    assert_not_nil item
    assert item.is_sealed_product?
    assert_equal "Booster Box Lorcana", item.card_name
    assert_equal 15500, item.allocated_cost_cents
    assert item.in_stock?
  end

  test "editing price/shipping while keep_sealed keeps the sealed item's allocated cost in sync" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0
    )

    purchase.update!(total_price_cents: 12000, shipping_cost_cents: 300)

    assert_equal 12300, purchase.sealed_inventory_item.allocated_cost_cents
  end

  test "copies the transient blueprint fields onto the sealed item when present" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0,
      cardtrader_blueprint_id: 777, category_id: 3, blueprint_image_url: "https://example.com/box.jpg"
    )

    item = purchase.sealed_inventory_item
    assert_equal 777, item.cardtrader_blueprint_id
    assert_equal 3, item.category_id
    assert_equal "https://example.com/box.jpg", item.image_url
  end

  test "switching from keep_sealed to crack_and_sell destroys the sealed item and unlocks unboxing" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0
    )

    assert_difference("InventoryItem.count", -1) do
      purchase.update!(intent_type: "crack_and_sell")
    end

    assert_nil purchase.sealed_inventory_item
  end

  test "blocks switching away from keep_sealed once the sealed item has been sold" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0
    )
    Sale.create!(inventory_item: purchase.sealed_inventory_item, sale_date: Date.current, sale_price_cents: 20000)

    purchase.intent_type = "crack_and_sell"

    assert_not purchase.save
    assert_includes purchase.errors[:intent_type], "non può passare a Spacchetta e Vendi: il prodotto sigillato risulta già venduto"
    assert purchase.reload.keep_sealed?
  end

  test "destroying a keep_sealed purchase destroys its sealed item too, unlike a crack_and_sell purchase" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0
    )

    assert_difference("InventoryItem.count", -1) do
      purchase.destroy!
    end
  end

  test "destroying a keep_sealed purchase whose sealed item was already sold is blocked entirely" do
    purchase = Purchase.create!(
      name: "Box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10000, shipping_cost_cents: 0
    )
    item = purchase.sealed_inventory_item
    Sale.create!(inventory_item: item, sale_date: Date.current, sale_price_cents: 20000)

    assert_not purchase.destroy

    assert Purchase.exists?(purchase.id)
    assert InventoryItem.exists?(item.id)
    assert_equal purchase.id, item.reload.purchase_id
  end
end
