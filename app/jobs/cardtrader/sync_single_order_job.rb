module Cardtrader
  # On-demand single-order import (spec §9.1 queue "ct_user_interactive":
  # "import singolo ordine" - highest priority, user is waiting on it).
  class SyncSingleOrderJob < ApplicationJob
    queue_as :ct_user_interactive

    retry_on Client::RateLimitError, Client::ConnectionError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.sync_run&.failed!(error.message)
    end

    discard_on Client::AuthenticationError, Client::NotFoundError do |job, error|
      job.sync_run&.failed!(error.message)
    end

    attr_reader :sync_run

    def perform(account_id, external_order_id, triggered_by_id: nil)
      account = Account.find(account_id)
      @sync_run = OrderSyncRun.create!(account: account, trigger: "manual", triggered_by_id: triggered_by_id)
      sync_run.running!

      SyncOrdersService.new(account).sync_one!(external_order_id, sync_run: sync_run)

      sync_run.succeeded!
    end
  end
end
