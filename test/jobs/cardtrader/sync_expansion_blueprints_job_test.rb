require "test_helper"

module Cardtrader
  class SyncExpansionBlueprintsJobTest < ActiveJob::TestCase
    setup do
      @run = CatalogSyncRun.create!(trigger: "schedule", status: "running", started_at: Time.current, expansions_total: 2)
    end

    test "upserts the expansion's blueprints and records progress on the run" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => ct_expansions(:war_of_the_spark).ct_id.to_s })
        .to_return(status: 200, body: [
          { "id" => 701, "name" => "Jace, the Mind Sculptor", "game_id" => 1, "category_id" => 1,
            "expansion_id" => ct_expansions(:war_of_the_spark).ct_id }
        ].to_json)

      SyncExpansionBlueprintsJob.perform_now(ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id, catalog_sync_run_id: @run.id)

      @run.reload
      assert_equal 1, @run.expansions_done
      assert_equal 1, @run.blueprints_upserted
      assert CtBlueprint.exists?(ct_id: 701)
    end

    test "marks the run completed once expansions_done reaches expansions_total" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => "null" }).to_return(status: 200, body: "[]")
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => ct_expansions(:war_of_the_spark).ct_id.to_s }).to_return(status: 200, body: "[]")

      SyncExpansionBlueprintsJob.perform_now(ct_expansion_id: nil, catalog_sync_run_id: @run.id)
      assert_equal "running", @run.reload.status

      SyncExpansionBlueprintsJob.perform_now(ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id, catalog_sync_run_id: @run.id)
      assert_equal "completed", @run.reload.status
    end

    test "discards without retrying on a 404, still counting the expansion as done with its error recorded" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => ct_expansions(:war_of_the_spark).ct_id.to_s })
        .to_return(status: 404, body: '{"error":"not found"}')

      # CatalogSyncRun's own Turbo Stream broadcasts legitimately enqueue
      # jobs too - only a retried/re-enqueued SyncExpansionBlueprintsJob matters here.
      assert_no_enqueued_jobs(only: SyncExpansionBlueprintsJob) do
        assert_nothing_raised do
          SyncExpansionBlueprintsJob.perform_now(ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id, catalog_sync_run_id: @run.id)
        end
      end

      @run.reload
      assert_equal 1, @run.expansions_done
      assert_equal 1, @run.sync_errors.size
    end

    test "retries with backoff on a 429, without yet counting the expansion as done" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => ct_expansions(:war_of_the_spark).ct_id.to_s })
        .to_return(status: 429, body: '{"error":"rate limited"}')

      assert_enqueued_with(job: SyncExpansionBlueprintsJob, queue: "ct_catalog") do
        assert_nothing_raised do
          SyncExpansionBlueprintsJob.perform_now(ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id, catalog_sync_run_id: @run.id)
        end
      end

      assert_equal 0, @run.reload.expansions_done
    end
  end
end
