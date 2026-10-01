require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
  end

  test "open_or_create! does not duplicate an already-open task for the same subject and kind" do
    assert_difference -> { Task.count }, 1 do
      2.times { Task.open_or_create!(kind: "credit_pending", subject: @account, account: @account) }
    end
  end

  test "open_or_create! opens a fresh task once a previous one for the same subject/kind was resolved" do
    first = Task.open_or_create!(kind: "credit_pending", subject: @account, account: @account)
    first.resolve!

    second = Task.open_or_create!(kind: "credit_pending", subject: @account, account: @account)

    assert_not_equal first.id, second.id
    assert_equal 2, Task.where(subject: @account, kind: "credit_pending").count
  end

  test "snooze! then unsnooze! round-trips back to open" do
    task = Task.open_or_create!(kind: "credit_pending", subject: @account, account: @account)

    task.snooze!(1.week.from_now)
    assert_equal "snoozed", task.status

    task.unsnooze!
    assert_equal "open", task.status
    assert_nil task.snoozed_until
  end

  test "dismiss! records the reason" do
    task = Task.open_or_create!(kind: "credit_pending", subject: @account, account: @account)

    task.dismiss!("false positive")

    assert_equal "dismissed", task.status
    assert_equal "false positive", task.resolution
    assert_not_nil task.resolved_at
  end
end
