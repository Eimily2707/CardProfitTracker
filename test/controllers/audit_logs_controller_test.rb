require "test_helper"

class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get audit_log_url(type: "Purchase", id: 1)
    assert_redirected_to new_session_url
  end

  test "an admin can view the audit trail for a purchase" do
    sign_in_as(users(:sara))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "A", currency: "EUR")
    purchase.update!(title: "B")

    get audit_log_url(type: "Purchase", id: purchase.id)

    assert_response :success
    assert_select "td", text: /B/
  end

  test "an owner can view the audit trail" do
    sign_in_as(users(:elena))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "A", currency: "EUR")

    get audit_log_url(type: "Purchase", id: purchase.id)

    assert_response :success
  end

  test "an operator is not authorized to view the audit trail" do
    sign_in_as(users(:operator_user))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "A", currency: "EUR")

    get audit_log_url(type: "Purchase", id: purchase.id)

    assert_redirected_to root_path
  end

  test "cannot view a record belonging to another account" do
    sign_in_as(users(:elena))
    other_purchase = accounts(:globex).purchases.create!(channel: channels(:globex_fair), title: "A", currency: "USD")

    get audit_log_url(type: "Purchase", id: other_purchase.id)

    assert_redirected_to root_path
  end

  test "rejects a non-auditable type" do
    sign_in_as(users(:elena))

    get audit_log_url(type: "User", id: users(:elena).id)

    assert_redirected_to root_path
  end
end
