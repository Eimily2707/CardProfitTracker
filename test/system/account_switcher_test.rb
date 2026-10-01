require "application_system_test_case"

class AccountSwitcherTest < ApplicationSystemTestCase
  test "switching the workspace in the header changes the current account" do
    user = users(:elena)
    accounts(:globex).memberships.create!(user: user, role: "operator")

    sign_in_as(user)
    assert_selector "p.text-lg", text: accounts(:acme).name

    find("select#account_id").select(accounts(:globex).name)

    assert_selector "p.text-lg", text: accounts(:globex).name
    assert_no_selector "p.text-lg", text: accounts(:acme).name
  end
end
