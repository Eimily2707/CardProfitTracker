require "test_helper"

module CostPools
  class RemoveItemServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 1000, cost_base_cents: 1000
      )
      @pool = OpenService.new(@sealed).call!
    end

    test "removing a manually-costed item frees its cost back to the pool's residual" do
      ChangeMethodService.new(@pool).call!("manual")
      items = [
        ExtractItemsService.new(@pool).call!(name: "Card A", kind: "single", quantity: 1, manual_cost_cents: 400).first,
        ExtractItemsService.new(@pool).call!(name: "Card B", kind: "single", quantity: 1, manual_cost_cents: 300).first
      ]
      assert_equal 300, @pool.reload.residual_base_cents

      RemoveItemService.new(@pool).call!(items.first)

      @pool.reload
      assert_equal 1, @pool.extracted_items.count
      assert_equal 300, @pool.allocated_base_cents
      assert_equal 700, @pool.residual_base_cents
      assert_equal "open", @pool.status
    end

    test "removing the last item under equal mode re-splits the pool across whoever remains" do
      items = ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 2)

      RemoveItemService.new(@pool).call!(items.first)

      @pool.reload
      assert_equal 1000, items.second.reload.cost_base_cents
      assert_equal 0, @pool.residual_base_cents
    end

    test "cannot remove a sold item" do
      item = ExtractItemsService.new(@pool).call!(name: "Card", kind: "single", quantity: 1).first
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 5_000)
      sale.confirm_payment!

      assert_raises(ArgumentError) { RemoveItemService.new(@pool).call!(item) }
    end

    test "rejects an item from a different pool" do
      other_sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Other Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 500, cost_base_cents: 500
      )
      other_pool = OpenService.new(other_sealed).call!
      other_item = ExtractItemsService.new(other_pool).call!(name: "Other Card", kind: "single", quantity: 1).first

      assert_raises(ArgumentError) { RemoveItemService.new(@pool).call!(other_item) }
    end
  end
end
