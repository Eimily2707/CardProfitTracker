module Cardtrader
  # Rereads one order after a webhook notification (spec §8.7/§9.1 queue
  # "ct_webhooks", priority 2). A webhook is only ever a hint that
  # something changed - this always refetches GET /orders/:id and applies
  # the state it finds, which is what makes a replayed/out-of-order
  # delivery harmless.
  class SyncOrderJob < ApplicationJob
    queue_as :ct_webhooks

    retry_on Client::RateLimitError, Client::ConnectionError,
             wait: :polynomially_longer, attempts: PendingOrderSync::MAX_ATTEMPTS do |job, error|
      job.pending_order_sync&.failed!
      job.open_import_failed_task!(error.message)
    end

    discard_on Client::AuthenticationError, Client::NotFoundError do |job, error|
      job.pending_order_sync&.give_up!
      job.connection&.mark_invalid!(error.message) if error.is_a?(Client::AuthenticationError)
      job.open_import_failed_task!(error.message)
    end

    attr_reader :pending_order_sync, :connection

    def perform(pending_order_sync_id)
      @pending_order_sync = PendingOrderSync.find(pending_order_sync_id)
      return unless pending_order_sync.status == "queued"

      @connection = pending_order_sync.connection
      pending_order_sync.running!

      SyncOrdersService.new(connection.account).sync_one!(pending_order_sync.ct_order_id)
      pending_order_sync.cancelled!
    end

    def open_import_failed_task!(message)
      return unless connection

      Task.open_or_create!(
        kind: "import_failed", subject: connection, account: connection.account,
        priority: "high", metadata: { error: message }
      )
    end
  end
end
