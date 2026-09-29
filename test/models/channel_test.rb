require "test_helper"

class ChannelTest < ActiveSupport::TestCase
  test "seed_defaults_for! creates one channel per SYSTEM_CHANNELS entry" do
    account = Account.create!(name: "New Shop", country: "IT", time_zone: "UTC")

    assert_equal Channel::SYSTEM_CHANNELS.size, account.channels.count
    assert account.channels.exists?(system_key: "cardtrader")
    assert_not account.channels.find_by(system_key: "cardtrader").allows_bundles
  end

  test "seeding is idempotent" do
    account = Account.create!(name: "New Shop", country: "IT", time_zone: "UTC")

    assert_no_difference -> { account.channels.count } do
      Channel.seed_defaults_for!(account)
    end
  end

  test "channel names are unique per account, not globally" do
    other = Account.create!(name: "Other Shop", country: "IT", time_zone: "UTC")

    assert_no_difference -> { Channel.count } do
      channel = other.channels.new(name: channels(:acme_fair).name, kind: "fair", usage: "both")
      assert_not channel.valid?
    end
  end

  test "a system channel cannot be destroyed" do
    channel = channels(:acme_fair)

    assert_not channel.destroy
    assert channel.errors[:base].present?
    assert Channel.exists?(channel.id)
  end

  test "a custom channel can be destroyed when it has no purchases" do
    channel = channels(:acme_private)

    assert channel.destroy
  end

  test "a channel with purchases cannot be destroyed" do
    channel = purchases(:acme_draft).channel

    assert_not channel.destroy
    assert Channel.exists?(channel.id)
  end
end
