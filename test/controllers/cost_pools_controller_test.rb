require "test_helper"

class CostPoolsControllerTest < ActionDispatch::IntegrationTest
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
    get cost_pool_url(@pool)
    assert_redirected_to new_session_url
  end

  test "shows the pool" do
    sign_in_as(users(:elena))

    get cost_pool_url(@pool)

    assert_response :success
  end

  test "does not show another account's pool" do
    sign_in_as(users(:elena))
    other_sealed = accounts(:globex).inventory_items.create!(
      kind: "sealed", name: "Other", intent: "crack", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:globex)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )
    other_pool = CostPools::OpenService.new(other_sealed).call!

    get cost_pool_url(other_pool)

    assert_response :not_found
  end

  test "an operator can change the allocation method" do
    sign_in_as(users(:elena))

    patch cost_pool_url(@pool), params: { allocation_method: "proportional" }

    assert_equal "proportional", @pool.reload.allocation_method
    assert_redirected_to @pool
  end

  test "a viewer cannot change the allocation method" do
    sign_in_as(users(:viewer_user))

    patch cost_pool_url(@pool), params: { allocation_method: "proportional" }

    assert_equal "equal", @pool.reload.allocation_method
  end

  test "close closes the pool once fully allocated" do
    sign_in_as(users(:elena))
    CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1)

    post close_cost_pool_url(@pool), params: { close_action: "distribute" }

    assert_equal "closed", @pool.reload.status
    assert_redirected_to @pool
  end

  test "reopen requires a reason" do
    sign_in_as(users(:elena))
    CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1)
    CostPools::CloseService.new(@pool).call!(action: "distribute")

    post reopen_cost_pool_url(@pool)

    assert_equal "closed", @pool.reload.status
  end

  test "an admin can reopen a closed pool with a reason" do
    sign_in_as(users(:sara))
    CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1)
    CostPools::CloseService.new(@pool).call!(action: "distribute")

    post reopen_cost_pool_url(@pool), params: { reason: "found another card" }

    assert_equal "open", @pool.reload.status
  end

  test "an operator cannot reopen a closed pool" do
    sign_in_as(users(:operator_user))
    CostPools::ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1)
    CostPools::CloseService.new(@pool).call!(action: "distribute")

    post reopen_cost_pool_url(@pool), params: { reason: "found another card" }

    assert_equal "closed", @pool.reload.status
  end
end
