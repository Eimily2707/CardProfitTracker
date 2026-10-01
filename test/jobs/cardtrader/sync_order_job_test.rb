require "test_helper"

module Cardtrader
  class SyncOrderJobTest < ActiveJob::TestCase
    setup do
      @connection = accounts(:acme).create_cardtrader_connection!(access_token: "token")
      @pending = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")
    end

    test "syncs the order and marks the pending sync cancelled" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/9001")
        .to_return(status: 200, body: { "id" => 9001, "state" => "hub_pending", "seller_total" => { "cents" => 1000, "currency" => "EUR" } }.to_json)

      SyncOrderJob.perform_now(@pending.id)

      assert_equal "cancelled", @pending.reload.status
      assert SaleOrder.exists?(external_order_id: "9001")
    end

    test "marks the connection invalid and opens an import_failed task on a 401" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/9001").to_return(status: 401, body: '{"error":"unauthorized"}')

      SyncOrderJob.perform_now(@pending.id)

      assert_equal "failed", @pending.reload.status
      assert_equal "invalid", @connection.reload.status
      assert Task.exists?(subject: @connection, kind: "import_failed", account: accounts(:acme))
    end

    test "does nothing if the pending sync is no longer queued" do
      @pending.update!(status: "cancelled")
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/9001")

      SyncOrderJob.perform_now(@pending.id)

      assert_not_requested :get, "https://api.cardtrader.com/api/v2/orders/9001"
    end
  end
end
