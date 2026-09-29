require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def valid_attributes
    { name: "Test Account", country: "IT", time_zone: "UTC" }
  end

  test "valid with just the required attributes, everything else defaulted" do
    account = Account.new(valid_attributes)
    assert account.valid?
    assert_equal "EUR", account.base_currency
    assert_equal "idle", account.rebase_status
    assert_equal "fifo", account.item_identification
    assert_equal "gross", account.vat_mode
    assert_equal "carryover", account.trade_valuation_method
  end

  test "requires a name" do
    account = Account.new(valid_attributes.merge(name: nil))
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "requires a 2-letter country code" do
    account = Account.new(valid_attributes.merge(country: "ITA"))
    assert_not account.valid?
    assert_includes account.errors[:country], "is the wrong length (should be 2 characters)"
  end

  test "requires a 3-letter base_currency" do
    account = Account.new(valid_attributes.merge(base_currency: "EURO"))
    assert_not account.valid?
    assert_includes account.errors[:base_currency], "is the wrong length (should be 3 characters)"
  end

  test "rejects an unsupported item_identification" do
    account = Account.new(valid_attributes.merge(item_identification: "random"))
    assert_not account.valid?
    assert_includes account.errors[:item_identification], "is not included in the list"
  end

  test "rejects a time_zone ActiveSupport::TimeZone does not recognize" do
    account = Account.new(valid_attributes.merge(time_zone: "Not/AZone"))
    assert_not account.valid?
    assert_includes account.errors[:time_zone], "is not a valid time zone"
  end

  test "rejects a negative label_threshold_cents" do
    account = Account.new(valid_attributes.merge(label_threshold_cents: -1))
    assert_not account.valid?
  end

  test "owner returns the user with the owner membership" do
    assert_equal users(:elena), accounts(:acme).owner
    assert_equal users(:marco), accounts(:globex).owner
  end

  test "has_many memberships and users through them" do
    assert_includes accounts(:acme).users, users(:elena)
    assert_includes accounts(:acme).users, users(:sara)
    assert_not_includes accounts(:acme).users, users(:marco)
  end

  test "destroying an account destroys its memberships and invitations" do
    account = Account.create!(valid_attributes)
    account.memberships.create!(user: users(:guest), role: "owner")
    account.invitations.create!(email: "x@example.com", role: "viewer")

    assert_difference [ "Membership.count", "Invitation.count" ], -1 do
      account.destroy!
    end
  end
end
