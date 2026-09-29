require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows the signed-in user's account once authenticated (Current.account populated post-auth)" do
    sign_in_as(users(:elena))

    get root_path

    assert_response :success
    assert_match "Acme Cards", response.body
    assert_match "elena@example.com", response.body
  end

  test "a user with no membership sees no account" do
    sign_in_as(users(:guest))

    get root_path

    assert_response :success
    assert_match "Nessun account", response.body
  end

  test "each user only ever sees their own account, never another tenant's" do
    sign_in_as(users(:marco))

    get root_path

    assert_response :success
    assert_match "Globex Trading", response.body
    assert_no_match "Acme Cards", response.body
  end
end
