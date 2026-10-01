require "test_helper"

class WriteOffTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @sealed = @account.inventory_items.create!(
      kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: 1000, cost_base_cents: 1000
    )
    @pool = CostPool.create!(account: @account, source_item: @sealed, total_base_cents: 1000)
  end

  test "requires either a cost_pool or an inventory_item" do
    write_off = WriteOff.new(account: @account, amount_base_cents: 100, reason: "unallocated_residual", occurred_on: Date.current)

    assert_not write_off.valid?
    assert write_off.errors.of_kind?(:base, :missing_target)
  end

  test "valid when attached to a cost pool" do
    write_off = WriteOff.new(account: @account, cost_pool: @pool, amount_base_cents: 100, reason: "bulk_waste", occurred_on: Date.current)

    assert write_off.valid?
  end

  test "requires a positive amount" do
    write_off = WriteOff.new(account: @account, cost_pool: @pool, amount_base_cents: 0, reason: "bulk_waste", occurred_on: Date.current)

    assert_not write_off.valid?
  end

  test "rejects an unknown reason" do
    write_off = WriteOff.new(account: @account, cost_pool: @pool, amount_base_cents: 100, reason: "bogus", occurred_on: Date.current)

    assert_not write_off.valid?
  end
end
