require "test_helper"

module Purchases
  class ReceiveServiceTest < ActiveSupport::TestCase
    setup do
      @purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
      @line = @purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)
      @line.update!(landed_base_cents: 200)
    end

    test "generate! is idempotent per line - calling it twice never duplicates items" do
      service = ReceiveService.new(@purchase)

      service.generate!(status: "pending_arrival")
      assert_equal 2, @line.inventory_items.count

      service.generate!(status: "pending_arrival")
      assert_equal 2, @line.inventory_items.reload.count
    end

    test "receive! only flips pending_arrival items, leaving others alone" do
      service = ReceiveService.new(@purchase)
      service.generate!(status: "pending_arrival")
      @purchase.inventory_items.first.update!(status: "voided")

      service.receive!

      assert_equal %w[in_stock voided].sort, @purchase.inventory_items.reload.pluck(:status).sort
    end

    test "void! only voids pending_arrival items" do
      service = ReceiveService.new(@purchase)
      service.generate!(status: "pending_arrival")

      service.void!

      assert @purchase.inventory_items.reload.all? { |item| item.status == "voided" }
    end
  end
end
