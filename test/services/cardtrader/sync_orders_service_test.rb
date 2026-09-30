require "test_helper"

module Cardtrader
  class SyncOrdersServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @service = SyncOrdersService.new(@account, client: Client.new(token: "test-token"))
    end

    def order_payload(id: 9001, state: "hub_pending", blueprint_id: ct_blueprints(:teferi).ct_id, seller_price_cents: 1500)
      {
        "id" => id,
        "code" => "ABC123",
        "transaction_code" => "TXN-1",
        "state" => state,
        "via_cardtrader_zero" => false,
        "presale" => false,
        "buyer" => { "username" => "buyer1" },
        "seller_total" => { "cents" => seller_price_cents, "currency" => "EUR" },
        "order_items" => [
          {
            "id" => 501,
            "blueprint_id" => blueprint_id,
            "name" => "Teferi, Time Raveler",
            "quantity" => 1,
            "seller_price" => { "cents" => seller_price_cents, "currency" => "EUR" }
          }
        ]
      }
    end

    def stub_orders(payloads)
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
        .with(query: hash_including({ "order_as" => "seller" }))
        .to_return(status: 200, body: payloads.to_json)
    end

    test "creates a SaleOrder and matches the line to an in-stock item by blueprint" do
      item = @account.inventory_items.create!(
        kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: 1.day.ago.to_date, public_ref: InventoryItem.generate_public_ref(@account),
        ct_blueprint: ct_blueprints(:teferi), acquisition_cost_base_cents: 500, cost_base_cents: 500
      )
      stub_orders([ order_payload ])

      created, updated, failures = @service.sync_all!

      assert_equal 1, created
      assert_equal 0, updated
      assert_empty failures

      sale = SaleOrder.find_by(external_order_id: "9001")
      assert_equal "paid", sale.status # hub_pending -> paid
      assert_equal "sold", item.reload.status
      assert_equal "fifo", sale.sale_lines.first.match_method
    end

    test "flags review_required when no inventory item matches the blueprint" do
      stub_orders([ order_payload ])

      @service.sync_all!

      sale = SaleOrder.find_by(external_order_id: "9001")
      assert sale.review_required?
      assert_equal "draft", sale.status # not auto-confirmed while a line is unmatched (spec US-5.2)
    end

    test "re-syncing the same order does not create a duplicate" do
      stub_orders([ order_payload ])
      @service.sync_all!

      stub_orders([ order_payload(state: "sent") ])
      created, updated, = @service.sync_all!

      assert_equal 0, created
      assert_equal 1, updated
      assert_equal 1, SaleOrder.where(external_order_id: "9001").count
    end

    test "sync_one! fetches and upserts a single order" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/9001")
        .to_return(status: 200, body: order_payload.to_json)

      was_new = @service.sync_one!(9001)

      assert was_new
      assert SaleOrder.exists?(external_order_id: "9001")
    end

    test "records progress on the given sync run" do
      sync_run = OrderSyncRun.create!(account: @account, trigger: "schedule")
      stub_orders([ order_payload ])

      @service.sync_all!(sync_run: sync_run)

      assert_equal 1, sync_run.reload.orders_created
    end
  end
end
