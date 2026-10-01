require "test_helper"

class CardtraderConnectionTest < ActiveSupport::TestCase
  test "generates a unique webhook_token on create" do
    connection = accounts(:acme).create_cardtrader_connection!(access_token: "token")

    assert connection.webhook_token.present?
  end

  test "access_token and shared_secret are stored encrypted" do
    connection = accounts(:acme).create_cardtrader_connection!(access_token: "super-secret-token")

    raw = ActiveRecord::Base.connection.select_value(
      "SELECT access_token FROM cardtrader_connections WHERE id = #{connection.id}"
    )
    assert_not_equal "super-secret-token", raw
    assert_equal "super-secret-token", connection.reload.access_token
  end

  test "verify! activates the connection on a successful GET /info" do
    connection = accounts(:acme).create_cardtrader_connection!(access_token: "token")
    stub_request(:get, "https://api.cardtrader.com/api/v2/info")
      .to_return(status: 200, body: { "id" => 42, "username" => "elena_ct", "shared_secret" => "shh" }.to_json)

    connection.verify!

    assert_equal "active", connection.status
    assert_equal "elena_ct", connection.ct_username
    assert_equal "shh", connection.shared_secret
  end

  test "verify! marks the connection invalid and re-raises on a 401" do
    connection = accounts(:acme).create_cardtrader_connection!(access_token: "bad-token")
    stub_request(:get, "https://api.cardtrader.com/api/v2/info").to_return(status: 401, body: '{"error":"unauthorized"}')

    assert_raises(Cardtrader::Client::AuthenticationError) { connection.verify! }
    assert_equal "invalid", connection.status
  end

  test "only one connection per account" do
    accounts(:acme).create_cardtrader_connection!(access_token: "token")

    assert_raises(ActiveRecord::RecordInvalid) do
      CardtraderConnection.create!(account: accounts(:acme), access_token: "another-token")
    end
  end
end
