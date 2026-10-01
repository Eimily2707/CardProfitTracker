require "test_helper"

module CostPools
  class SetManualCostServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
      ChangeMethodService.new(@pool).call!("manual")
      @item = ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 2).first
    end

    test "sets the item's cost and refreshes the pool cache" do
      SetManualCostService.new(@pool).call!(@item, 700)

      assert_equal 700, @item.reload.cost_base_cents
      assert_equal "pool_manual", @item.cost_source
      assert_equal 700, @pool.reload.allocated_base_cents
    end

    test "raises when the new cost would exceed the pool" do
      assert_raises(ActiveRecord::RecordInvalid) { SetManualCostService.new(@pool).call!(@item, 2_000) }
    end

    test "rejects equal/proportional pools" do
      ChangeMethodService.new(@pool).call!("equal")

      assert_raises(ArgumentError) { SetManualCostService.new(@pool).call!(@item, 100) }
    end

    test "cannot set the cost of a sold item" do
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: @item, description: @item.name, unit_price_cents: 5_000)
      sale.confirm_payment!

      assert_raises(ArgumentError) { SetManualCostService.new(@pool).call!(@item, 100) }
    end
  end
end
