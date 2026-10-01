require "test_helper"

module Webhooks
  class CardtraderControllerTest < ActionDispatch::IntegrationTest
    setup do
      @connection = accounts(:acme).create_cardtrader_connection!(access_token: "token", shared_secret: "s3cr3t", status: "active")
    end

    def signed_post(body, secret: "s3cr3t")
      signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, body))
      post cardtrader_webhook_path(webhook_token: @connection.webhook_token),
           params: body, headers: { "Signature" => signature, "Content-Type" => "application/json" }
    end

    test "accepts a validly-signed live order webhook and enqueues a re-read" do
      body = { object_id: 9001, cause: "order.paid", mode: "live", time: Time.now.to_i }.to_json

      assert_enqueued_with(job: Cardtrader::SyncOrderJob) do
        signed_post(body)
      end

      assert_response :success
      event = WebhookEvent.last
      assert_equal "accepted", event.status
      assert_equal "9001", event.ct_object_id
    end

    test "rejects a request with a bad signature and logs it without enqueuing anything" do
      body = { object_id: 9001, cause: "order.paid", mode: "live", time: Time.now.to_i }.to_json

      assert_no_enqueued_jobs only: Cardtrader::SyncOrderJob do
        signed_post(body, secret: "wrong-secret")
      end

      assert_response :unauthorized
      assert_equal "rejected", WebhookEvent.last.status
    end

    test "rejects a request for an unknown or inactive webhook_token" do
      post cardtrader_webhook_path(webhook_token: "does-not-exist"), params: "{}", headers: { "Content-Type" => "application/json" }

      assert_response :unauthorized
    end

    test "records a test-mode event without enqueuing a sync" do
      body = { object_id: 9001, cause: "order.paid", mode: "test", time: Time.now.to_i }.to_json

      assert_no_enqueued_jobs only: Cardtrader::SyncOrderJob do
        signed_post(body)
      end

      assert_response :success
      assert_equal "test", WebhookEvent.last.status
    end

    test "a second notification for the same order while one is pending does not enqueue a duplicate" do
      body = { object_id: 9001, cause: "order.paid", mode: "live", time: Time.now.to_i }.to_json

      signed_post(body)
      assert_enqueued_jobs 1, only: Cardtrader::SyncOrderJob

      signed_post(body)
      assert_enqueued_jobs 1, only: Cardtrader::SyncOrderJob
    end

    test "replaying the same signed body twice is harmless (idempotent)" do
      body = { object_id: 9001, cause: "order.paid", mode: "live", time: Time.now.to_i }.to_json

      signed_post(body)
      assert_response :success

      signed_post(body)
      assert_response :success
    end
  end
end
