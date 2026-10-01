require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get tasks_url
    assert_redirected_to new_session_url
  end

  test "lists open and snoozed tasks for the account" do
    sign_in_as(users(:elena))
    account = accounts(:acme)
    Task.create!(account: account, subject: account, kind: "credit_pending", priority: "normal")

    get tasks_url

    assert_response :success
  end

  test "snoozing a task moves it out of the open list until reopened" do
    sign_in_as(users(:elena))
    account = accounts(:acme)
    task = Task.create!(account: account, subject: account, kind: "credit_pending", priority: "normal")

    post snooze_task_url(task)

    assert_equal "snoozed", task.reload.status
    assert_not_nil task.snoozed_until
  end

  test "dismissing a task closes it" do
    sign_in_as(users(:elena))
    account = accounts(:acme)
    task = Task.create!(account: account, subject: account, kind: "credit_pending", priority: "normal")

    post dismiss_task_url(task), params: { reason: "not relevant" }

    assert_equal "dismissed", task.reload.status
    assert_equal "not relevant", task.resolution
  end

  test "a viewer cannot dismiss a task" do
    sign_in_as(users(:viewer_user))
    account = accounts(:acme)
    task = Task.create!(account: account, subject: account, kind: "credit_pending", priority: "normal")

    post dismiss_task_url(task)

    assert_equal "open", task.reload.status
  end

  test "does not expose another account's tasks" do
    sign_in_as(users(:elena))
    other = accounts(:globex)
    task = Task.create!(account: other, subject: other, kind: "credit_pending", priority: "normal")

    post dismiss_task_url(task)

    assert_response :not_found
  end
end
