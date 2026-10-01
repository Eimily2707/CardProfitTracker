require "test_helper"

module CostPools
  class AllocationServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
    end

    def extract(quantity:, reference_value_cents: nil, manual_cost_cents: nil)
      ExtractItemsService.new(@pool).call!(
        name: "Card", kind: "single", quantity: quantity, reference_value_cents: reference_value_cents, manual_cost_cents: manual_cost_cents
      )
    end

    test "equal splits the pool evenly with the largest-remainder method, cent-perfect" do
      extract(quantity: 3)

      costs = @pool.reload.extracted_items.order(:id).pluck(:cost_base_cents)
      assert_equal [ 334, 333, 333 ], costs
      assert_equal 1000, costs.sum
      assert_equal "allocated", @pool.status
    end

    test "proportional weighs by reference_value_cents" do
      extract(quantity: 1, reference_value_cents: 100)
      extract(quantity: 1, reference_value_cents: 300)
      ChangeMethodService.new(@pool).call!("proportional")

      costs = @pool.reload.extracted_items.order(:reference_value_cents).pluck(:cost_base_cents)
      assert_equal [ 250, 750 ], costs
    end

    test "proportional gives zero-weight items nothing when some items have a reference value" do
      extract(quantity: 1, reference_value_cents: 0)
      extract(quantity: 1, reference_value_cents: 500)
      ChangeMethodService.new(@pool).call!("proportional")

      costs = @pool.reload.extracted_items.order(:reference_value_cents).pluck(:cost_base_cents)
      assert_equal [ 0, 1000 ], costs
    end

    test "hybrid keeps manually-costed items fixed and splits the remainder equally" do
      ChangeMethodService.new(@pool).call!("hybrid")
      manual_item = extract(quantity: 1, manual_cost_cents: 400).first
      extract(quantity: 2)

      @pool.reload
      assert_equal 400, manual_item.reload.cost_base_cents
      auto_costs = @pool.extracted_items.where.not(id: manual_item.id).pluck(:cost_base_cents)
      assert_equal [ 300, 300 ], auto_costs
      assert_equal 1000, @pool.allocated_base_cents
    end

    test "hybrid raises when manual costs alone exceed the pool" do
      ChangeMethodService.new(@pool).call!("hybrid")

      assert_raises(AllocationService::PoolExceededError) { extract(quantity: 1, manual_cost_cents: 1500) }
    end

    test "sold items are locked and never touched by recalculation" do
      items = extract(quantity: 2)
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: items.first, description: items.first.name, unit_price_cents: 5_000)
      sale.confirm_payment!

      locked_cost = items.first.reload.cost_base_cents
      extract(quantity: 1) # triggers a fresh recalculation across all unlocked items

      assert_equal locked_cost, items.first.reload.cost_base_cents
      assert_equal 1000, @pool.reload.allocated_base_cents
    end

    test "raises when locked item costs already exceed the pool total" do
      items = extract(quantity: 1)
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: items.first, description: items.first.name, unit_price_cents: 5_000)
      sale.confirm_payment!

      # bypasses CostPool's own validation - simulates total_base_cents being
      # reduced out from under an already-locked cost by some other path,
      # which AllocationService must still defend against on its own.
      @pool.update_column(:total_base_cents, 500)

      assert_raises(AllocationService::PoolExceededError) { AllocationService.new(@pool).recalculate! }
    end

    test "manual method leaves item costs untouched across recalculation" do
      ChangeMethodService.new(@pool).call!("manual")
      item = extract(quantity: 1, manual_cost_cents: 250).first

      AllocationService.new(@pool).recalculate!

      assert_equal 250, item.reload.cost_base_cents
      assert_equal "open", @pool.reload.status # residual (750) still open
    end
  end
end
