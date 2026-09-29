module Cardtrader
  # Downloads and upserts the blueprint export for a single expansion
  # (ct_expansion_id nil for blueprints with no expansion, §9.6). Enqueued
  # per-expansion by SyncCatalogJob; several can run concurrently since each
  # covers an independent expansion.
  class SyncExpansionBlueprintsJob < ApplicationJob
    queue_as :ct_catalog

    limits_concurrency key: "sync_expansion_blueprints", to: 3, on_conflict: :block

    retry_on Client::RateLimitError, Client::ConnectionError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.record_expansion_failure!(error)
    end

    discard_on Client::AuthenticationError, Client::NotFoundError do |job, error|
      job.record_expansion_failure!(error)
    end

    def perform(ct_expansion_id:, catalog_sync_run_id:)
      @ct_expansion_id = ct_expansion_id
      @catalog_sync_run = CatalogSyncRun.find(catalog_sync_run_id)

      upserted, removed = CatalogSync.new.sync_blueprints_for_expansion!(ct_expansion_id)
      catalog_sync_run.record_expansion_progress!(blueprints_upserted: upserted, blueprints_removed: removed)
      finalize_run_if_complete
    end

    # Public: invoked as a retry_on/discard_on failure callback (job, error),
    # so this expansion still counts as "done" (with its error recorded)
    # instead of leaving the whole run stuck short of its total forever.
    def record_expansion_failure!(error)
      return unless catalog_sync_run

      catalog_sync_run.with_lock do
        catalog_sync_run.update!(sync_errors: catalog_sync_run.sync_errors + [ "expansion #{@ct_expansion_id.inspect}: #{error.message}" ])
      end
      catalog_sync_run.record_expansion_progress!
      finalize_run_if_complete
    end

    private

    attr_reader :catalog_sync_run

    def finalize_run_if_complete
      catalog_sync_run.reload
      return if catalog_sync_run.status == "completed"

      catalog_sync_run.completed! if catalog_sync_run.expansions_done >= catalog_sync_run.expansions_total
    end
  end
end
