require "test_helper"

module Cardtrader
  class SyncCatalogJobTest < ActiveJob::TestCase
    setup do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games").to_return(status: 200, body: "[]")
      stub_request(:get, "https://api.cardtrader.com/api/v2/categories").to_return(status: 200, body: "[]")
    end

    test "creates a CatalogSyncRun and enqueues one SyncExpansionBlueprintsJob per enabled expansion plus one for nil" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: [
          { "id" => ct_expansions(:war_of_the_spark).ct_id, "game_id" => 1, "code" => "WAR", "name" => "War of the Spark" }
        ].to_json)

      assert_difference("CatalogSyncRun.count", 1) do
        assert_enqueued_jobs 2, only: SyncExpansionBlueprintsJob do
          SyncCatalogJob.perform_now(trigger: "schedule")
        end
      end

      run = CatalogSyncRun.order(:created_at).last
      assert_equal "running", run.status
      assert_equal 2, run.expansions_total

      assert_enqueued_with(job: SyncExpansionBlueprintsJob,
                            args: [ { ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id, catalog_sync_run_id: run.id } ])
      assert_enqueued_with(job: SyncExpansionBlueprintsJob,
                            args: [ { ct_expansion_id: nil, catalog_sync_run_id: run.id } ])
    end

    test "records a manual trigger with its triggering user" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions").to_return(status: 200, body: "[]")

      SyncCatalogJob.perform_now(trigger: "manual", triggered_by_id: users(:elena).id)

      run = CatalogSyncRun.order(:created_at).last
      assert_equal "manual", run.trigger
      assert_equal users(:elena), run.triggered_by
    end

    test "retries (without marking the run failed yet) on a rate-limit error" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 429, body: '{"error":"rate limited"}')

      assert_enqueued_with(job: SyncCatalogJob) do
        SyncCatalogJob.perform_now(trigger: "schedule")
      end

      run = CatalogSyncRun.order(:created_at).last
      assert_equal "running", run.status
    end

    test "marks the run failed immediately when the token is missing or invalid (discard_on, no retry)" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 401, body: '{"error":"unauthorized"}')

      # CatalogSyncRun's own Turbo Stream broadcasts (create, running!,
      # failed!) legitimately enqueue jobs too - only SyncExpansionBlueprintsJob matters here.
      assert_no_enqueued_jobs(only: SyncExpansionBlueprintsJob) do
        assert_nothing_raised { SyncCatalogJob.perform_now(trigger: "schedule") }
      end

      run = CatalogSyncRun.order(:created_at).last
      assert_equal "failed", run.status
      assert_equal 1, run.sync_errors.size
    end
  end
end
