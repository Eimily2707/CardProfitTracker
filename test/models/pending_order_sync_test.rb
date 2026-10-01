require "test_helper"

class PendingOrderSyncTest < ActiveSupport::TestCase
  setup do
    @connection = accounts(:acme).create_cardtrader_connection!(access_token: "token")
  end

  test "request! coalesces a second call for the same order while one is queued" do
    first = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")
    second = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")

    assert_not_nil first
    assert_nil second
    assert_equal 1, PendingOrderSync.where(connection: @connection, ct_order_id: "9001").count
  end

  test "request! allows a fresh sync once the previous one has settled" do
    first = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")
    first.cancelled!

    second = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")

    assert_not_nil second
    assert_equal 2, PendingOrderSync.where(connection: @connection, ct_order_id: "9001").count
  end

  test "failed! retries until MAX_ATTEMPTS, then settles as failed" do
    pending = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")

    (PendingOrderSync::MAX_ATTEMPTS - 1).times do
      pending.failed!
      assert_equal "queued", pending.status
    end

    pending.failed!
    assert_equal "failed", pending.status
    assert pending.exhausted?
  end

  test "give_up! settles as failed immediately, regardless of attempt count" do
    pending = PendingOrderSync.request!(connection: @connection, ct_order_id: "9001")

    pending.give_up!

    assert_equal "failed", pending.status
    assert_equal 0, pending.attempts
  end
end
