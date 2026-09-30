require "test_helper"

module Sales
  class FulfillSaleServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @sale = @account.sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
      @item = @account.inventory_items.create!(
        kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 500, cost_base_cents: 500
      )
      @line = @sale.sale_lines.create!(inventory_item: @item, description: "Teferi", unit_price_cents: 1000)
    end

    test "reserve! requires the item to be in_stock" do
      @item.update!(status: "sold")

      assert_raises(ArgumentError) { FulfillSaleService.new(@sale).reserve! }
    end

    test "reserve! moves an in_stock item to reserved" do
      FulfillSaleService.new(@sale).reserve!
      assert_equal "reserved", @item.reload.status
    end

    test "mark_sold! snapshots the item's current cost on the line" do
      FulfillSaleService.new(@sale).mark_sold!

      assert_equal "sold", @item.reload.status
      assert_equal 500, @line.reload.cost_base_cents_snapshot
    end

    test "release! returns a reserved or sold item to in_stock" do
      FulfillSaleService.new(@sale).mark_sold!
      FulfillSaleService.new(@sale).release!

      assert_equal "in_stock", @item.reload.status
    end

    test "release! ignores cancelled lines" do
      FulfillSaleService.new(@sale).mark_sold!
      @line.update!(status: "cancelled")

      FulfillSaleService.new(@sale).release!

      assert_equal "sold", @item.reload.status
    end
  end
end
