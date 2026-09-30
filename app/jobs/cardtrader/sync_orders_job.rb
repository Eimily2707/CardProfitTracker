module Cardtrader
  # Bulk seller-order sync for one account's CardTrader connection (spec
  # §9.1 queue "ct_user_bulk": "Import per intervallo, riconciliazione").
  class SyncOrdersJob < ApplicationJob
    queue_as :ct_user_bulk

    # One sync per account at a time, rather than queueing a duplicate.
    limits_concurrency key: ->(account_id, **) { "sync_orders_#{account_id}" }, to: 1, on_conflict: :discard

    retry_on Client::RateLimitError, Client::ConnectionError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.sync_run&.failed!(error.message)
    end

    discard_on Client::AuthenticationError, Client::NotFoundError do |job, error|
      job.sync_run&.failed!(error.message)
    end

    attr_reader :sync_run

    def perform(account_id, trigger: "manual", triggered_by_id: nil)
      account = Account.find(account_id)
      @sync_run = OrderSyncRun.create!(account: account, trigger: trigger, triggered_by_id: triggered_by_id)
      sync_run.running!

      SyncOrdersService.new(account).sync_all!(sync_run: sync_run)

      sync_run.succeeded!
    end
  end
end
