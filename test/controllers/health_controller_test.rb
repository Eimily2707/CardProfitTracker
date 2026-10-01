require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "reports failure when no Solid Queue worker has a recent heartbeat" do
    get rails_health_check_url

    assert_response :internal_server_error
    assert_includes @response.body, "queue"
  end

  test "reports OK when the database is reachable and a worker heartbeat is recent" do
    SolidQueue::Process.create!(
      kind: "Worker", pid: 1, hostname: "test", last_heartbeat_at: Time.current,
      supervisor_id: nil, metadata: {}, name: "test-worker-#{SecureRandom.hex(4)}"
    )

    get rails_health_check_url

    assert_response :success
    assert_includes @response.body, "OK"
  end
end
