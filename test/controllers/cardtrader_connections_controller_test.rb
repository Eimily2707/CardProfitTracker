require "test_helper"

class CardtraderConnectionsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get new_cardtrader_connection_url
    assert_redirected_to new_session_url
  end

  test "an owner can create a connection" do
    sign_in_as(users(:elena))

    assert_difference -> { CardtraderConnection.count }, 1 do
      post cardtrader_connection_url, params: { cardtrader_connection: { access_token: "secret-token" } }
    end

    assert_redirected_to edit_cardtrader_connection_url
    assert_equal "pending_verification", accounts(:acme).reload.cardtrader_connection.status
  end

  test "an operator cannot create a connection" do
    sign_in_as(users(:operator_user))

    assert_no_difference -> { CardtraderConnection.count } do
      post cardtrader_connection_url, params: { cardtrader_connection: { access_token: "secret-token" } }
    end
  end

  test "verify calls the CardTrader API and activates the connection" do
    sign_in_as(users(:elena))
    accounts(:acme).create_cardtrader_connection!(access_token: "secret-token")
    stub_request(:get, "https://api.cardtrader.com/api/v2/info")
      .to_return(status: 200, body: { "id" => 1, "username" => "elena_ct", "shared_secret" => "shh" }.to_json)

    post verify_cardtrader_connection_url

    assert_redirected_to edit_cardtrader_connection_url
    connection = accounts(:acme).reload.cardtrader_connection
    assert_equal "active", connection.status
    assert_equal "elena_ct", connection.ct_username
  end

  test "verify shows an alert instead of raising when the token is invalid" do
    sign_in_as(users(:elena))
    accounts(:acme).create_cardtrader_connection!(access_token: "bad-token")
    stub_request(:get, "https://api.cardtrader.com/api/v2/info").to_return(status: 401, body: '{"error":"unauthorized"}')

    post verify_cardtrader_connection_url

    assert_redirected_to edit_cardtrader_connection_url
    assert_equal "invalid", accounts(:acme).reload.cardtrader_connection.status
  end

  test "destroy disconnects rather than deleting the row" do
    sign_in_as(users(:elena))
    connection = accounts(:acme).create_cardtrader_connection!(access_token: "secret-token")

    delete cardtrader_connection_url

    assert_equal "disconnected", connection.reload.status
  end
end
