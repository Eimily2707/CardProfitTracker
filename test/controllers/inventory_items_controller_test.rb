require "test_helper"

class InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @purchase = purchases(:lorcana_box)
  end

  test "creates an inventory item under a purchase, converting euro cost to cents" do
    assert_difference("InventoryItem.count", 1) do
      post purchase_inventory_items_url(@purchase), params: {
        inventory_item: {
          cardtrader_blueprint_id: 501, image_url: "https://example.com/card.jpg",
          card_name: "New Card", set_name: "Some Set",
          condition: "NM", language: "EN", is_foil: "0", allocated_cost: "12.50"
        }
      }
    end

    item = InventoryItem.order(:created_at).last
    assert_redirected_to purchase_url(@purchase)
    assert_equal @purchase, item.purchase
    assert_equal 1250, item.allocated_cost_cents
  end

  test "does not create an invalid inventory item" do
    assert_no_difference("InventoryItem.count") do
      post purchase_inventory_items_url(@purchase), params: { inventory_item: { card_name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "destroys an inventory item and redirects back to its purchase" do
    item = inventory_items(:elsa_foil)

    assert_difference("InventoryItem.count", -1) do
      delete inventory_item_url(item)
    end

    assert_redirected_to purchase_url(@purchase)
  end

  test "destroying an item with no purchase redirects to the purchases index" do
    item = inventory_items(:manual_entry)

    assert_difference("InventoryItem.count", -1) do
      delete inventory_item_url(item)
    end

    assert_redirected_to purchases_url
  end

  test "destroying an already-sold item is blocked with an alert" do
    item = inventory_items(:mickey_common) # has the mickey_sale fixture attached

    assert_no_difference("InventoryItem.count") do
      delete inventory_item_url(item)
    end

    assert_redirected_to purchase_url(@purchase)
    follow_redirect!
    assert_match "già venduta", response.body
  end
end
