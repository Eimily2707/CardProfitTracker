require "test_helper"

module CostPools
  class CloseServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
    end

    test "distribute closes the pool once the formula brings the residual to zero" do
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 3)

      CloseService.new(@pool).call!(action: "distribute")

      assert_equal "closed", @pool.reload.status
      assert_equal 0, @pool.residual_base_cents
      assert_equal [ "close" ], @pool.state_transitions.pluck(:event)
    end

    test "write_off closes the pool by recording its residual as a loss" do
      ChangeMethodService.new(@pool).call!("manual")
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1, manual_cost_cents: 400)

      CloseService.new(@pool).call!(action: "write_off", reason: "bulk_waste", occurred_on: Date.current)

      @pool.reload
      assert_equal "closed", @pool.status
      assert_equal 0, @pool.residual_base_cents
      write_off = @pool.write_offs.sole
      assert_equal 600, write_off.amount_base_cents
      assert_equal "bulk_waste", write_off.reason
    end

    test "absorb_bulk_lot closes the pool by creating an item that eats the residual" do
      ChangeMethodService.new(@pool).call!("manual")
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1, manual_cost_cents: 250)

      CloseService.new(@pool).call!(action: "absorb_bulk_lot")

      @pool.reload
      assert_equal "closed", @pool.status
      assert_equal 0, @pool.residual_base_cents
      absorber = @pool.extracted_items.find_by(kind: "bulk_lot")
      assert_equal 750, absorber.cost_base_cents
    end

    test "write_off raises when there is no residual to write off" do
      ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1) # equal -> fully allocated

      assert_raises(ArgumentError) { CloseService.new(@pool).call!(action: "write_off") }
    end

    test "rejects an unknown close action" do
      assert_raises(ArgumentError) { CloseService.new(@pool).call!(action: "bogus") }
    end
  end
end
