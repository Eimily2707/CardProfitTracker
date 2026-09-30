require "test_helper"

module Cardtrader
  class SyncOrdersJobTest < ActiveJob::TestCase
    test "creates an OrderSyncRun and records a successful sync" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
        .with(query: hash_including({ "order_as" => "seller" }))
        .to_return(status: 200, body: "[]")

      assert_difference("Cardtrader::OrderSyncRun.count", 1) do
        SyncOrdersJob.perform_now(accounts(:acme).id, trigger: "schedule")
      end

      run = OrderSyncRun.order(:created_at).last
      assert_equal "succeeded", run.status
      assert_equal accounts(:acme), run.account
    end

    test "records a manual trigger with its triggering user" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
        .with(query: hash_including({ "order_as" => "seller" }))
        .to_return(status: 200, body: "[]")

      SyncOrdersJob.perform_now(accounts(:acme).id, trigger: "manual", triggered_by_id: users(:elena).id)

      run = OrderSyncRun.order(:created_at).last
      assert_equal "manual", run.trigger
      assert_equal users(:elena), run.triggered_by
    end
  end
end
