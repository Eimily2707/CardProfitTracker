module Cardtrader
  # Entry point for a full catalog sync (§9.6): games, categories,
  # expansions, then one SyncExpansionBlueprintsJob per expansion of an
  # enabled game (plus one for blueprints with no expansion). Progress is
  # tracked on a CatalogSyncRun, broadcast to the UI as it updates.
  class SyncCatalogJob < ApplicationJob
    queue_as :ct_catalog

    # Avoid two full syncs running at once (e.g. a manual trigger while the
    # nightly schedule is still in flight) rather than queueing a duplicate.
    limits_concurrency key: "sync_catalog", to: 1, on_conflict: :discard

    retry_on Client::RateLimitError, Client::ConnectionError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.catalog_sync_run&.failed!(error.message)
    end

    discard_on Client::AuthenticationError, Client::NotFoundError do |job, error|
      job.catalog_sync_run&.failed!(error.message)
    end

    attr_reader :catalog_sync_run

    def perform(trigger: "schedule", triggered_by_id: nil)
      @catalog_sync_run = CatalogSyncRun.create!(trigger: trigger, triggered_by_id: triggered_by_id)
      catalog_sync_run.running!

      sync = CatalogSync.new
      sync.sync_games!
      sync.sync_categories!
      enabled_expansion_ct_ids = sync.sync_expansions!

      # nil stands for blueprints with no expansion (§9.6) - counted as one more target.
      targets = enabled_expansion_ct_ids + [ nil ]
      catalog_sync_run.update!(expansions_total: targets.size)

      targets.each do |ct_expansion_id|
        SyncExpansionBlueprintsJob.perform_later(ct_expansion_id: ct_expansion_id, catalog_sync_run_id: catalog_sync_run.id)
      end
    end
  end
end
