require "test_helper"

class MembershipPolicyTest < ActiveSupport::TestCase
  setup do
    @operator_membership = Membership.create!(account: accounts(:acme), user: users(:guest), role: "operator")
  end

  test "owner can update and destroy any membership, including admins" do
    policy = MembershipPolicy.new(users(:elena), memberships(:acme_admin))
    assert policy.update?
    assert policy.destroy?
  end

  test "owner can update and destroy an operator membership" do
    policy = MembershipPolicy.new(users(:elena), @operator_membership)
    assert policy.update?
    assert policy.destroy?
  end

  test "admin can update and destroy a non-owner membership" do
    policy = MembershipPolicy.new(users(:sara), @operator_membership)
    assert policy.update?
    assert policy.destroy?
  end

  test "admin cannot update or destroy the owner's membership" do
    policy = MembershipPolicy.new(users(:sara), memberships(:acme_owner))
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "operator and viewer cannot manage memberships at all" do
    viewer_membership = Membership.create!(account: accounts(:acme), user: users(:marco), role: "viewer")

    operator_policy = MembershipPolicy.new(users(:guest), @operator_membership)
    assert_not operator_policy.update?

    viewer_policy = MembershipPolicy.new(viewer_membership.user, @operator_membership)
    assert_not viewer_policy.update?
  end

  test "a user outside the account cannot manage its memberships" do
    policy = MembershipPolicy.new(users(:marco), memberships(:acme_admin))
    assert_not policy.update?
    assert_not policy.destroy?
  end

  test "Scope resolves only memberships within the user's own accounts" do
    resolved = MembershipPolicy::Scope.new(users(:elena), Membership).resolve

    assert_includes resolved, memberships(:acme_owner)
    assert_includes resolved, memberships(:acme_admin)
    assert_not_includes resolved, memberships(:globex_owner)
  end
end
