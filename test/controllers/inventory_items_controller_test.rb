require "test_helper"

class InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
  end

  def create_item(kind: "single", status: "in_stock", name: "Card", location: nil, acquired_on: Date.current, cost_cents: 500)
    @account.inventory_items.create!(
      kind: kind, name: name, intent: "sell", status: status, cost_source: "manual", location: location,
      acquired_on: acquired_on, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: cost_cents, cost_base_cents: cost_cents
    )
  end

  test "requires authentication" do
    get inventory_items_url
    assert_redirected_to new_session_url
  end

  test "lists the account's inventory" do
    sign_in_as(users(:elena))
    create_item(name: "Black Lotus")

    get inventory_items_url

    assert_response :success
    assert_select "td", text: /Black Lotus/
  end

  test "does not list another account's inventory" do
    sign_in_as(users(:elena))
    other = accounts(:globex)
    other.inventory_items.create!(
      kind: "single", name: "Not mine", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(other),
      acquisition_cost_base_cents: 100, cost_base_cents: 100
    )

    get inventory_items_url

    assert_response :success
    assert_select "td", text: /Not mine/, count: 0
  end

  test "filters by kind and status" do
    sign_in_as(users(:elena))
    create_item(name: "Single card", kind: "single")
    create_item(name: "Sealed box", kind: "sealed")

    get inventory_items_url(kind: "sealed")

    assert_select "td", text: /Sealed box/
    assert_select "td", text: /Single card/, count: 0
  end

  test "exports the filtered set as csv" do
    sign_in_as(users(:elena))
    create_item(name: "Black Lotus")

    get inventory_items_url(format: :csv)

    assert_response :success
    assert_match "Black Lotus", response.body
  end

  test "show renders the item detail and history" do
    sign_in_as(users(:elena))
    item = create_item(name: "Black Lotus")

    get inventory_item_url(item)

    assert_response :success
  end

  test "open creates a cost pool for a sealed item and redirects to it" do
    sign_in_as(users(:elena))
    item = create_item(name: "Booster Box", kind: "sealed", cost_cents: 5_000)

    assert_difference -> { CostPool.count }, 1 do
      post open_inventory_item_url(item)
    end

    assert_equal "opened", item.reload.status
    assert_redirected_to cost_pool_path(CostPool.last)
  end

  test "a viewer cannot open a sealed item" do
    sign_in_as(users(:viewer_user))
    item = create_item(name: "Booster Box", kind: "sealed", cost_cents: 5_000)

    assert_no_difference -> { CostPool.count } do
      post open_inventory_item_url(item)
    end
  end

  test "open rejects a single card" do
    sign_in_as(users(:elena))
    item = create_item(name: "Black Lotus", kind: "single")

    post open_inventory_item_url(item)

    assert_redirected_to item
    assert_equal "in_stock", item.reload.status
  end
end
