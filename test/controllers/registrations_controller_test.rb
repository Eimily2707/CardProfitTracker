require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.config.x.public_registration_enabled = true
  end

  teardown do
    Rails.application.config.x.public_registration_enabled = false
  end

  test "redirects to sign in when public registration is disabled" do
    Rails.application.config.x.public_registration_enabled = false

    get new_registration_url

    assert_redirected_to new_session_url
  end

  test "shows the registration form when enabled" do
    get new_registration_url
    assert_response :success
  end

  test "creates a user, an account, and an owner membership, then signs the user in" do
    assert_difference([ "User.count", "Account.count", "Membership.count" ], 1) do
      post registration_url, params: {
        user: { name: "Nome Nuovo", email: "new-owner@example.com", password: "password123" },
        account: { name: "Nuovo Workspace", country: "IT" }
      }
    end

    assert_redirected_to root_url
    assert cookies[:session_id]

    user = User.find_by(email: "new-owner@example.com")
    membership = user.memberships.sole
    assert_equal "owner", membership.role
    assert_equal "Nuovo Workspace", membership.account.name
  end

  test "does not create anything when the account is invalid" do
    assert_no_difference([ "User.count", "Account.count", "Membership.count" ]) do
      post registration_url, params: {
        user: { name: "Nome", email: "broken@example.com", password: "password123" },
        account: { name: "Workspace", country: "ITALY" }
      }
    end

    assert_response :unprocessable_entity
    assert_nil User.find_by(email: "broken@example.com")
  end

  test "does not create anything when the user is invalid" do
    assert_no_difference([ "User.count", "Account.count", "Membership.count" ]) do
      post registration_url, params: {
        user: { name: "Nome", email: "", password: "password123" },
        account: { name: "Workspace", country: "IT" }
      }
    end

    assert_response :unprocessable_entity
  end
end
