require "test_helper"

module CostPools
  class OpenServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
    end

    def build_item(kind: "sealed", status: "in_stock")
      @account.inventory_items.create!(
        kind: kind, name: "Booster Box", intent: "crack", status: status, cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 5_000, cost_base_cents: 5_000
      )
    end

    test "creates a pool with the item's own cost and moves the item to opened" do
      item = build_item

      pool = OpenService.new(item).call!

      assert_equal 5_000, pool.total_base_cents
      assert_equal "open", pool.status
      assert_equal "equal", pool.allocation_method
      assert_equal item, pool.source_item
      assert_equal "opened", item.reload.status
    end

    test "rejects an item that is not in_stock" do
      item = build_item(status: "sold")

      assert_raises(ArgumentError) { OpenService.new(item).call! }
    end

    test "rejects a single-card item" do
      item = build_item(kind: "single")

      assert_raises(ArgumentError) { OpenService.new(item).call! }
    end

    test "accepts a bulk_lot item too" do
      item = build_item(kind: "bulk_lot")

      pool = OpenService.new(item).call!

      assert_equal "opened", item.reload.status
      assert_equal item, pool.source_item
    end

    test "rejects an item that already has a pool" do
      item = build_item
      OpenService.new(item).call!
      item.update_column(:status, "in_stock") # simulate a re-opened item still pointing at a pool

      assert_raises(ArgumentError) { OpenService.new(item).call! }
    end
  end
end
