require "test_helper"

class AccountSwitchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Give elena a second account so switching is actually meaningful.
    @second_account = Account.create!(name: "Elena's Second Shop", country: "IT", time_zone: "UTC")
    Membership.create!(account: @second_account, user: users(:elena), role: "owner")
  end

  test "switches Current.account and remembers the choice in a cookie" do
    sign_in_as(users(:elena))

    post switch_account_url, params: { account_id: @second_account.id }

    assert_redirected_to root_url
    assert_equal @second_account.id.to_s, cookies[:current_account_id]

    follow_redirect!
    assert_match ERB::Util.html_escape(@second_account.name), response.body
  end

  test "ignores an account_id the user is not a member of" do
    sign_in_as(users(:elena))

    post switch_account_url, params: { account_id: accounts(:globex).id }

    assert_redirected_to root_url
    assert_nil cookies[:current_account_id]
  end

  test "the remembered account is used on the next request" do
    sign_in_as(users(:elena))
    post switch_account_url, params: { account_id: @second_account.id }

    get root_url

    assert_match ERB::Util.html_escape(@second_account.name), response.body
  end
end
