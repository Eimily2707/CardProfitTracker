require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @invitation = invitations(:acme_pending)
    # Fixtures are raw SQL inserts, so they never run assign_token - only its
    # digest is stored. This is the known raw value behind that fixture's
    # token_digest (see test/fixtures/invitations.yml).
    @raw_token = "test-token-raw"
  end

  test "owner can view the pending invitations list" do
    sign_in_as(users(:elena))
    get invitations_url
    assert_response :success
    assert_match @invitation.email, response.body
  end

  test "viewer cannot view the pending invitations list" do
    Membership.create!(account: accounts(:acme), user: users(:guest), role: "viewer")
    sign_in_as(users(:guest))

    get invitations_url

    assert_redirected_to root_url
  end

  test "owner can invite a collaborator, enqueuing the invitation email" do
    sign_in_as(users(:elena))

    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      assert_difference("Invitation.count", 1) do
        post invitations_url, params: { invitation: { email: "friend@example.com", role: "operator" } }
      end
    end

    assert_redirected_to invitations_url
    invitation = Invitation.order(:created_at).last
    assert_equal accounts(:acme), invitation.account
    assert_equal users(:elena), invitation.invited_by
  end

  test "viewer cannot create an invitation" do
    Membership.create!(account: accounts(:acme), user: users(:guest), role: "viewer")
    sign_in_as(users(:guest))

    assert_no_difference("Invitation.count") do
      post invitations_url, params: { invitation: { email: "friend@example.com", role: "operator" } }
    end

    assert_redirected_to root_url
  end

  test "rejects assigning the owner role via invitation" do
    sign_in_as(users(:elena))

    assert_no_difference("Invitation.count") do
      post invitations_url, params: { invitation: { email: "friend@example.com", role: "owner" } }
    end

    assert_response :unprocessable_entity
  end

  test "owner can revoke a pending invitation" do
    sign_in_as(users(:elena))

    assert_difference("Invitation.count", -1) do
      delete invitation_url(@invitation)
    end

    assert_redirected_to invitations_url
  end

  test "a member of a different account cannot revoke it" do
    sign_in_as(users(:marco))

    assert_no_difference("Invitation.count") do
      delete invitation_url(@invitation)
    end

    assert_redirected_to root_url
  end

  test "shows the public accept page for an anonymous visitor" do
    get invitation_preview_url(@raw_token)
    assert_response :success
    assert_match @invitation.email, response.body
  end

  test "redirects with an alert for an unknown token" do
    get invitation_preview_url("not-a-real-token")
    assert_redirected_to new_session_url
  end

  test "redirects with an alert for an expired invitation" do
    @invitation.update!(expires_at: 1.hour.ago)

    get invitation_preview_url(@raw_token)

    assert_redirected_to new_session_url
  end

  test "redirects with an alert for an already-accepted invitation" do
    @invitation.accept!

    get invitation_preview_url(@raw_token)

    assert_redirected_to new_session_url
  end

  test "an anonymous visitor accepting creates a user pinned to the invited email, and a membership" do
    assert_difference([ "User.count", "Membership.count" ], 1) do
      post accept_invitation_url(@raw_token), params: { user: { name: "Friend", password: "password123" } }
    end

    assert_redirected_to root_url
    assert cookies[:session_id]

    user = User.find_by(email: @invitation.email)
    assert_equal "Friend", user.name
    assert_equal "operator", user.memberships.sole.role
    assert @invitation.reload.accepted?
  end

  test "ignores an email supplied in params, always using the invited address" do
    post accept_invitation_url(@raw_token), params: { user: { name: "Friend", email: "hijack@example.com", password: "password123" } }

    assert_nil User.find_by(email: "hijack@example.com")
    assert User.find_by(email: @invitation.email)
  end

  test "a signed-in user accepting joins with the invitation's role instead of creating a new user" do
    sign_in_as(users(:marco))

    assert_no_difference("User.count") do
      assert_difference("Membership.count", 1) do
        post accept_invitation_url(@raw_token)
      end
    end

    assert_redirected_to root_url
    assert_equal "operator", users(:marco).memberships.find_by(account: accounts(:acme)).role
    assert @invitation.reload.accepted?
  end

  test "a signed-in user who is already a member just accepts, without a duplicate membership" do
    sign_in_as(users(:sara))

    assert_no_difference("Membership.count") do
      post accept_invitation_url(@raw_token)
    end

    assert_redirected_to root_url
    assert @invitation.reload.accepted?
  end
end
