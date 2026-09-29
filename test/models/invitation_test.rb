require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "valid with an account, email and role" do
    invitation = Invitation.new(account: accounts(:acme), email: "friend@example.com", role: "operator")
    assert invitation.valid?
  end

  test "requires an account (TenantScoped)" do
    invitation = Invitation.new(email: "friend@example.com", role: "operator")
    assert_not invitation.valid?
    assert_includes invitation.errors[:account], "must exist"
  end

  test "rejects owner as an invitation role" do
    invitation = Invitation.new(account: accounts(:acme), email: "friend@example.com", role: "owner")
    assert_not invitation.valid?
    assert_includes invitation.errors[:role], "is not included in the list"
  end

  test "defaults expires_at to 7 days from creation" do
    invitation = Invitation.create!(account: accounts(:acme), email: "friend@example.com", role: "viewer")
    assert_in_delta 7.days.from_now.to_i, invitation.expires_at.to_i, 5
  end

  test "generates a token whose digest is what gets persisted" do
    invitation = Invitation.create!(account: accounts(:acme), email: "friend@example.com", role: "viewer")

    assert_not_nil invitation.token
    assert_equal Invitation.digest(invitation.token), invitation.token_digest
    assert_not_equal invitation.token, invitation.token_digest
  end

  test "find_by_token locates the invitation matching the raw token" do
    invitation = Invitation.create!(account: accounts(:acme), email: "friend@example.com", role: "viewer")

    assert_equal invitation, Invitation.find_by_token(invitation.token)
    assert_nil Invitation.find_by_token("not-the-right-token")
    assert_nil Invitation.find_by_token(nil)
  end

  test "expired? reflects expires_at" do
    invitation = invitations(:acme_pending)
    assert_not invitation.expired?

    invitation.update!(expires_at: 1.hour.ago)
    assert invitation.expired?
  end

  test "accept! stamps accepted_at" do
    invitation = invitations(:acme_pending)
    assert_not invitation.accepted?

    invitation.accept!

    assert invitation.accepted?
    assert_not_nil invitation.accepted_at
  end

  test "for_account scopes to only that account's invitations" do
    other = Invitation.create!(account: accounts(:globex), email: "someone@example.com", role: "viewer")

    scoped = Invitation.for_account(accounts(:acme))

    assert_includes scoped, invitations(:acme_pending)
    assert_not_includes scoped, other
  end
end
