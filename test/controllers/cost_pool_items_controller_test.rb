require "test_helper"

class CostPoolItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @sealed = @account.inventory_items.create!(
      kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: 1000, cost_base_cents: 1000
    )
    @pool = CostPools::OpenService.new(@sealed).call!
  end

  test "requires authentication" do
    post cost_pool_items_url(@pool), params: { name: "Card", kind: "single", quantity: 1 }
    assert_redirected_to new_session_url
  end

  test "create extracts items into the pool" do
    sign_in_as(users(:elena))

    assert_difference -> { @pool.extracted_items.count }, 2 do
      post cost_pool_items_url(@pool), params: { name: "Card", kind: "single", quantity: 2 }
    end

    assert_redirected_to @pool
  end

  test "a viewer cannot extract items" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { @pool.extracted_items.count } do
      post cost_pool_items_url(@pool), params: { name: "Card", kind: "single", quantity: 1 }
    end
  end

  test "update sets a manual cost under the manual method" do
    sign_in_as(users(:elena))
    patch cost_pool_url(@pool), params: { allocation_method: "manual" }
    item = CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1).first

    patch cost_pool_item_url(@pool, item), params: { cost: "4.00" }

    assert_equal 400, item.reload.cost_base_cents
    assert_redirected_to @pool
  end

  test "update rejects a manual cost that exceeds the pool" do
    sign_in_as(users(:elena))
    patch cost_pool_url(@pool), params: { allocation_method: "manual" }
    item = CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1).first

    patch cost_pool_item_url(@pool, item), params: { cost: "20.00" }

    assert_not_equal 2000, item.reload.cost_base_cents
    assert_redirected_to @pool
  end

  test "destroy removes the item from the pool" do
    sign_in_as(users(:elena))
    item = CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1).first

    assert_difference -> { @pool.extracted_items.count }, -1 do
      delete cost_pool_item_url(@pool, item)
    end
  end
end
