require "test_helper"

class AccountPolicyTest < ActiveSupport::TestCase
  setup do
    @acme = accounts(:acme)
  end

  test "owner can view, update, and touch owner-only settings" do
    policy = AccountPolicy.new(users(:elena), @acme)

    assert policy.show?
    assert policy.update?
    assert policy.update_base_currency?
    assert policy.update_time_zone?
    assert policy.update_item_identification?
    assert policy.manage_members?
    assert policy.connect_cardtrader?
    assert policy.export_data?
    assert policy.destroy?
  end

  test "admin can view, update, and manage members, but not owner-only settings" do
    policy = AccountPolicy.new(users(:sara), @acme)

    assert policy.show?
    assert policy.update?
    assert policy.manage_members?
    assert policy.connect_cardtrader?
    assert_not policy.update_base_currency?
    assert_not policy.update_time_zone?
    assert_not policy.update_item_identification?
    assert_not policy.export_data?
    assert_not policy.destroy?
  end

  test "a user with no membership cannot even view the account" do
    policy = AccountPolicy.new(users(:guest), @acme)
    assert_not policy.show?
  end

  test "a member of a different account cannot view this one" do
    policy = AccountPolicy.new(users(:marco), @acme)
    assert_not policy.show?
  end

  test "Scope resolves only the accounts the user belongs to" do
    resolved = AccountPolicy::Scope.new(users(:elena), Account).resolve
    assert_includes resolved, accounts(:acme)
    assert_not_includes resolved, accounts(:globex)
  end
end
