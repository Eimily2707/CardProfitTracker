require "test_helper"

class CostPoolTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @sealed = @account.inventory_items.create!(
      kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: 10_000, cost_base_cents: 10_000
    )
  end

  test "residual_base_cents is total minus allocated minus written off" do
    pool = CostPool.create!(account: @account, source_item: @sealed, total_base_cents: 1000, allocated_base_cents: 300, written_off_base_cents: 100)

    assert_equal 600, pool.residual_base_cents
  end

  test "is invalid when the residual would be negative" do
    pool = CostPool.new(account: @account, source_item: @sealed, total_base_cents: 1000, allocated_base_cents: 1200)

    assert_not pool.valid?
  end

  test "refresh_automatic_status! flips between open and allocated but never touches a closed pool" do
    pool = CostPool.create!(account: @account, source_item: @sealed, total_base_cents: 1000, allocated_base_cents: 0)

    pool.refresh_automatic_status!
    assert_equal "open", pool.status

    pool.update!(allocated_base_cents: 1000)
    pool.refresh_automatic_status!
    assert_equal "allocated", pool.status

    pool.log_transition!(event: "close", to: "closed")
    pool.refresh_automatic_status!
    assert_equal "closed", pool.status
  end

  test "recovery_percent is nil when the pool total is zero" do
    pool = CostPool.create!(account: @account, source_item: @sealed, total_base_cents: 0)

    assert_nil pool.recovery_percent
  end

  test "recovery_percent is the credited net proceeds of sold descendants over the pool total" do
    pool = CostPools::OpenService.new(@sealed).call!
    item = CostPools::ExtractItemsService.new(pool).call!(name: "Card", kind: "single", quantity: 1).first

    sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 9_000)
    sale.confirm_payment!

    assert_equal 0.0, pool.recovery_percent, "not credited yet"

    sale.ship!
    sale.deliver!
    sale.mark_credited!

    assert_equal 90.0, pool.recovery_percent
  end
end
