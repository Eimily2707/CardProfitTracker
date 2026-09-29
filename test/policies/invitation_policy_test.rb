require "test_helper"

class InvitationPolicyTest < ActiveSupport::TestCase
  setup do
    @invitation = invitations(:acme_pending)
  end

  test "owner can create and destroy invitations" do
    policy = InvitationPolicy.new(users(:elena), @invitation)
    assert policy.index?
    assert policy.create?
    assert policy.destroy?
  end

  test "admin can create and destroy invitations" do
    policy = InvitationPolicy.new(users(:sara), @invitation)
    assert policy.index?
    assert policy.create?
    assert policy.destroy?
  end

  test "operator and viewer cannot create or destroy invitations" do
    operator_membership = Membership.create!(account: accounts(:acme), user: users(:guest), role: "operator")

    policy = InvitationPolicy.new(operator_membership.user, @invitation)
    assert_not policy.index?
    assert_not policy.create?
    assert_not policy.destroy?
  end

  test "a user outside the account cannot manage its invitations" do
    policy = InvitationPolicy.new(users(:marco), @invitation)
    assert_not policy.create?
    assert_not policy.destroy?
  end

  test "Scope resolves only invitations within the user's own accounts" do
    other = Invitation.create!(account: accounts(:globex), email: "someone@example.com", role: "viewer")

    resolved = InvitationPolicy::Scope.new(users(:elena), Invitation).resolve

    assert_includes resolved, @invitation
    assert_not_includes resolved, other
  end
end
