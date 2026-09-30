require "test_helper"

module Cardtrader
  class SyncSingleOrderJobTest < ActiveJob::TestCase
    test "imports one order by id and records success" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/9001")
        .to_return(status: 200, body: { "id" => 9001, "state" => "hub_pending", "seller_total" => { "cents" => 1000, "currency" => "EUR" } }.to_json)

      assert_difference [ "Cardtrader::OrderSyncRun.count", "SaleOrder.count" ], 1 do
        SyncSingleOrderJob.perform_now(accounts(:acme).id, 9001, triggered_by_id: users(:elena).id)
      end

      run = OrderSyncRun.order(:created_at).last
      assert_equal "succeeded", run.status
      assert_equal 1, run.orders_created
    end
  end
end
