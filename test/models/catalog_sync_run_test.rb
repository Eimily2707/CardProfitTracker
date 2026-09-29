require "test_helper"

class CatalogSyncRunTest < ActiveSupport::TestCase
  test "valid with a trigger of schedule and no triggered_by" do
    run = CatalogSyncRun.new(trigger: "schedule")
    assert run.valid?
  end

  test "requires triggered_by when the trigger is manual" do
    run = CatalogSyncRun.new(trigger: "manual")
    assert_not run.valid?
    assert_includes run.errors[:triggered_by], "can't be blank"
  end

  test "valid when manual and triggered_by is set" do
    run = CatalogSyncRun.new(trigger: "manual", triggered_by: users(:elena))
    assert run.valid?
  end

  test "defaults to pending status" do
    assert_equal "pending", CatalogSyncRun.new.status
  end

  test "sync_errors reads/writes the errors column without colliding with ActiveModel::Validations#errors" do
    run = CatalogSyncRun.create!(trigger: "schedule")

    assert_equal [], run.sync_errors
    assert_kind_of ActiveModel::Errors, run.errors

    run.update!(sync_errors: [ "boom" ])
    assert_equal [ "boom" ], run.reload.sync_errors
  end

  test "running! stamps started_at and sets status" do
    run = CatalogSyncRun.create!(trigger: "schedule")
    run.running!

    assert_equal "running", run.status
    assert_not_nil run.started_at
  end

  test "completed! stamps finished_at and sets status" do
    run = CatalogSyncRun.create!(trigger: "schedule")
    run.completed!

    assert_equal "completed", run.status
    assert_not_nil run.finished_at
  end

  test "failed! stamps finished_at, sets status and appends the error message" do
    run = CatalogSyncRun.create!(trigger: "schedule")
    run.failed!("network exploded")

    assert_equal "failed", run.status
    assert_not_nil run.finished_at
    assert_includes run.sync_errors, "network exploded"
  end

  test "record_expansion_progress! increments counters" do
    run = CatalogSyncRun.create!(trigger: "schedule", expansions_total: 2)

    run.record_expansion_progress!(blueprints_upserted: 10, blueprints_removed: 1)

    assert_equal 1, run.expansions_done
    assert_equal 10, run.blueprints_upserted
    assert_equal 1, run.blueprints_removed
  end

  test "record_expansion_progress! accumulates across multiple calls" do
    run = CatalogSyncRun.create!(trigger: "schedule", expansions_total: 2)

    run.record_expansion_progress!(blueprints_upserted: 10)
    run.record_expansion_progress!(blueprints_upserted: 5, blueprints_removed: 2)

    assert_equal 2, run.expansions_done
    assert_equal 15, run.blueprints_upserted
    assert_equal 2, run.blueprints_removed
  end
end
