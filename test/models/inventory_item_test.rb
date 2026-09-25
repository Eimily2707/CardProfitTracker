require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  test "valid with only a card_name" do
    item = InventoryItem.new(card_name: "Test Card")
    assert item.valid?
  end

  test "invalid without a card_name" do
    item = InventoryItem.new(card_name: nil)
    assert_not item.valid?
    assert_includes item.errors[:card_name], "can't be blank"
  end

  test "condition must be one of the allowed values" do
    item = InventoryItem.new(card_name: "Test", condition: "XYZ")
    assert_not item.valid?
    assert_includes item.errors[:condition], "is not included in the list"
  end

  test "condition can be left blank" do
    item = InventoryItem.new(card_name: "Test", condition: nil)
    assert item.valid?
  end

  test "accepts every documented condition" do
    InventoryItem::CONDITIONS.each do |condition|
      item = InventoryItem.new(card_name: "Test", condition: condition)
      assert item.valid?, "expected condition #{condition.inspect} to be valid"
    end
  end

  test "rejects a negative allocated_cost_cents" do
    item = InventoryItem.new(card_name: "Test", allocated_cost_cents: -1)
    assert_not item.valid?
    assert_includes item.errors[:allocated_cost_cents], "must be greater than or equal to 0"
  end

  test "defaults to the in_stock status" do
    assert_equal "in_stock", InventoryItem.new.status
  end

  test "status enum exposes predicate and bang helpers for every allowed value" do
    item = inventory_items(:mickey_common)
    assert item.sold?

    item.in_stock!
    assert_equal "in_stock", item.reload.status

    item.personal_collection!
    assert_equal "personal_collection", item.reload.status
  end

  test "rejects a status outside the enum" do
    item = InventoryItem.new(card_name: "Test", status: "lost")
    assert_not item.valid?
    assert_includes item.errors[:status], "is not included in the list"
  end

  test "purchase is optional" do
    item = InventoryItem.new(card_name: "Orphan card")
    assert_nil item.purchase
    assert item.valid?
  end

  test "belongs to a purchase when one is set" do
    item = inventory_items(:elsa_foil)
    assert_equal purchases(:lorcana_box), item.purchase
  end

  test "a fixture can exist without any purchase" do
    item = inventory_items(:manual_entry)
    assert_nil item.purchase
    assert item.valid?
  end

  test "has_one sale" do
    item = inventory_items(:mickey_common)
    assert_equal sales(:mickey_sale), item.sale
  end
end
