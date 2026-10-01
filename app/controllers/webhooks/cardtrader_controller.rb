module Webhooks
  # spec §8.7, literal reference implementation. Deliberately independent of
  # ApplicationController/Authentication - CardTrader never has a session,
  # only the per-connection webhook_token in the path and the HMAC
  # signature. A webhook is a notification "order X changed", never a
  # source of state itself: the actual sync always rereads GET
  # /orders/:id (Cardtrader::SyncOrderJob), which makes replays harmless.
  class CardtraderController < ActionController::API
    def create
      connection = CardtraderConnection.active.find_by(webhook_token: params[:webhook_token])
      return head(:unauthorized) unless connection

      body = request.raw_post
      data = parse(body)

      if valid_signature?(connection, body)
        record_event!(connection, data, status: data["mode"] == "test" ? "test" : "accepted")
        request_sync!(connection, data) if data["mode"] == "live"
        head :ok
      else
        record_event!(connection, data, status: "rejected")
        head :unauthorized
      end
    end

    private

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError
      {}
    end

    # spec §8.7: Signature = Base64(HMAC-SHA256(shared_secret, raw JSON
    # body)), compared at constant time, computed on request.raw_post
    # before any parsing.
    def valid_signature?(connection, body)
      return false if connection.shared_secret.blank?

      expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", connection.shared_secret, body))
      given = request.headers["Signature"].to_s
      ActiveSupport::SecurityUtils.secure_compare(expected, given)
    end

    def record_event!(connection, data, status:)
      WebhookEvent.create!(
        connection: connection, ct_object_id: data["object_id"].to_s.presence || "unknown", cause: data["cause"],
        mode: data["mode"].presence || "live", event_time: data["time"] ? Time.at(data["time"].to_i) : Time.current,
        status: status
      )
    end

    # spec §8.7 "Coalescenza": PendingOrderSync.request! is itself the
    # dedup - a second notification for an order already queued is a no-op.
    def request_sync!(connection, data)
      pending = PendingOrderSync.request!(connection: connection, ct_order_id: data["object_id"].to_s)
      Cardtrader::SyncOrderJob.perform_later(pending.id) if pending
    end
  end
end
