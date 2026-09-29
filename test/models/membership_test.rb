require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "valid with an account, a user and a role" do
    membership = Membership.new(account: accounts(:acme), user: users(:guest), role: "viewer")
    assert membership.valid?
  end

  test "requires an account (TenantScoped)" do
    membership = Membership.new(user: users(:guest), role: "viewer")
    assert_not membership.valid?
    assert_includes membership.errors[:account], "must exist"
  end

  test "rejects a role outside the 4 defined ones" do
    membership = Membership.new(account: accounts(:acme), user: users(:guest), role: "superuser")
    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "a user can only have one membership per account" do
    duplicate = Membership.new(account: accounts(:acme), user: users(:elena), role: "viewer")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "the same user can belong to several accounts" do
    membership = Membership.new(account: accounts(:globex), user: users(:elena), role: "viewer")
    assert membership.valid?
  end

  test "rejects a second owner for the same account" do
    second_owner = Membership.new(account: accounts(:acme), user: users(:guest), role: "owner")
    assert_not second_owner.valid?
    assert_includes second_owner.errors[:role], "there can only be one owner per account"
  end

  test "blocks demoting the account's only owner" do
    owner_membership = memberships(:acme_owner)
    owner_membership.role = "admin"

    assert_not owner_membership.valid?
    assert_includes owner_membership.errors[:role], "cannot remove the account's last owner"
  end

  test "blocks destroying the account's only owner" do
    owner_membership = memberships(:acme_owner)

    assert_not owner_membership.destroy
    assert Membership.exists?(owner_membership.id)
  end

  test "the owner role can never be changed or removed through the normal path" do
    # There's never "another owner" to fall back on: only_one_owner_per_account
    # (and a matching DB partial unique index) never let a second owner
    # membership exist for the same account in the first place.
    assert_raises(ActiveRecord::RecordInvalid) do
      Membership.create!(account: accounts(:acme), user: users(:guest), role: "owner")
    end
  end

  test "role predicate methods" do
    assert memberships(:acme_owner).owner?
    assert_not memberships(:acme_owner).admin?
    assert memberships(:acme_admin).admin?
  end

  test "role_label is translated" do
    I18n.with_locale(:it) do
      assert_equal "Proprietario", memberships(:acme_owner).role_label
    end

    I18n.with_locale(:en) do
      assert_equal "Owner", memberships(:acme_owner).role_label
    end
  end

  test "for_account scopes to only that account's memberships" do
    scoped = Membership.for_account(accounts(:acme))

    assert_includes scoped, memberships(:acme_owner)
    assert_includes scoped, memberships(:acme_admin)
    assert_not_includes scoped, memberships(:globex_owner)
  end
end
