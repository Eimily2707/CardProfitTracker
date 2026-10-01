require "test_helper"

class WebhookEventTest < ActiveSupport::TestCase
  setup do
    @connection = accounts(:acme).create_cardtrader_connection!(access_token: "token")
  end

  test "valid with a connection, ct_object_id, mode, status and event_time" do
    event = WebhookEvent.new(
      connection: @connection, ct_object_id: "9001", cause: "created",
      mode: "live", status: "accepted", event_time: Time.current
    )

    assert event.valid?
  end

  test "requires ct_object_id" do
    event = WebhookEvent.new(connection: @connection, mode: "live", status: "accepted", event_time: Time.current)

    assert_not event.valid?
    assert event.errors.of_kind?(:ct_object_id, :blank)
  end

  test "rejects an unknown mode or status" do
    event = WebhookEvent.new(
      connection: @connection, ct_object_id: "9001", mode: "bogus", status: "bogus", event_time: Time.current
    )

    assert_not event.valid?
    assert event.errors.of_kind?(:mode, :inclusion)
    assert event.errors.of_kind?(:status, :inclusion)
  end

  test "expired scope returns only events older than the retention window" do
    fresh = WebhookEvent.create!(
      connection: @connection, ct_object_id: "1", mode: "live", status: "accepted",
      event_time: Time.current, created_at: 1.day.ago
    )
    stale = WebhookEvent.create!(
      connection: @connection, ct_object_id: "2", mode: "live", status: "accepted",
      event_time: Time.current, created_at: (WebhookEvent::RETENTION + 1.day).ago
    )

    assert_includes WebhookEvent.expired, stale
    assert_not_includes WebhookEvent.expired, fresh
  end
end
