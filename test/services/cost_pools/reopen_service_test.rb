require "test_helper"

module CostPools
  class ReopenServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
      ChangeMethodService.new(@pool).call!("manual")
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1, manual_cost_cents: 400)
      CloseService.new(@pool).call!(action: "write_off", reason: "unallocated_residual", occurred_on: Date.current)
    end

    test "reverses the residual write-off and reopens the pool" do
      assert_equal 1, @pool.write_offs.count

      ReopenService.new(@pool).call!(reason: "found more cards")

      @pool.reload
      assert_equal "open", @pool.status
      assert_equal 0, @pool.write_offs.count
      assert_equal 600, @pool.residual_base_cents
      assert_equal [ "reopen" ], @pool.state_transitions.where(event: "reopen").pluck(:event)
      assert_equal "found more cards", @pool.state_transitions.last.reason
    end

    test "raises when the pool is not closed" do
      ReopenService.new(@pool).call!(reason: "x")
      @pool.reload

      assert_raises(ArgumentError) { ReopenService.new(@pool).call!(reason: "y") }
    end
  end
end
