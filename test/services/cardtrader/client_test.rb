require "test_helper"

module Cardtrader
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(token: "test-token")
    end

    test "raises AuthenticationError without an API token configured" do
      original_token = ENV.delete("CARDTRADER_API_TOKEN")
      client = Client.new(token: nil)

      assert_raises(Client::AuthenticationError) { client.games }
    ensure
      ENV["CARDTRADER_API_TOKEN"] = original_token
    end

    test "sends the bearer token and accept header on every request" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/games")
             .with(headers: { "Authorization" => "Bearer test-token", "Accept" => "application/json" })
             .to_return(status: 200, body: [ { "id" => 1, "name" => "Magic: The Gathering" } ].to_json)

      result = @client.games

      assert_requested stub
      assert_equal [ { "id" => 1, "name" => "Magic: The Gathering" } ], result
    end

    test "categories includes the game_id filter when given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/categories")
             .with(query: { "game_id" => "1" })
             .to_return(status: 200, body: [ { "id" => 1, "game_id" => 1, "name" => "Magic Single" } ].to_json)

      result = @client.categories(game_id: 1)

      assert_requested stub
      assert_equal 1, result.length
    end

    test "categories omits the game_id filter when not given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/categories").to_return(status: 200, body: "[]")

      @client.categories

      assert_requested stub
    end

    test "expansions includes the game_id filter when given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
             .with(query: { "game_id" => "1" })
             .to_return(status: 200, body: [ { "id" => 10, "game_id" => 1, "name" => "War of the Spark" } ].to_json)

      result = @client.expansions(game_id: 1)

      assert_requested stub
      assert_equal 1, result.length
    end

    test "blueprints_export sends the required expansion_id parameter" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
             .with(query: { "expansion_id" => "10" })
             .to_return(status: 200, body: [ { "id" => 501, "name" => "Elsa - Snow Queen" } ].to_json)

      result = @client.blueprints_export(expansion_id: 10)

      assert_requested stub
      assert_equal "Elsa - Snow Queen", result.first["name"]
    end

    test "blueprints_export accepts the literal expansion_id \"null\"" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
             .with(query: { "expansion_id" => "null" })
             .to_return(status: 200, body: "[]")

      @client.blueprints_export(expansion_id: "null")

      assert_requested stub
    end

    test "orders defaults to the buyer role and default pagination" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
             .with(query: { "order_as" => "buyer", "limit" => "20", "page" => "1" })
             .to_return(status: 200, body: [ { "id" => 1 } ].to_json)

      result = @client.orders

      assert_requested stub
      assert_equal 1, result.length
    end

    test "order fetches a single order by id" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders/42")
             .to_return(status: 200, body: { "id" => 42, "state" => "paid" }.to_json)

      result = @client.order(42)

      assert_requested stub
      assert_equal "paid", result["state"]
    end

    test "raises RateLimitError on a 429 response" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 429, body: '{"error":"Too many requests: max 200 requests per 10 seconds"}')

      error = assert_raises(Client::RateLimitError) { @client.games }
      assert_equal 429, error.status
      assert_kind_of Client::ApiError, error
    end

    test "raises AuthenticationError on a 401 response" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 401, body: '{"error":"unauthorized"}')

      error = assert_raises(Client::AuthenticationError) { @client.games }
      assert_equal 401, error.status
    end

    test "raises NotFoundError on a 404 response" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 404, body: '{"error":"not found"}')

      error = assert_raises(Client::NotFoundError) { @client.games }
      assert_equal 404, error.status
    end

    test "raises ConnectionError on a network failure" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games").to_timeout

      assert_raises(Client::ConnectionError) { @client.games }
    end

    test "raises the generic ApiError on an unexpected non-2xx response" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 500, body: "internal server error")

      error = assert_raises(Client::ApiError) { @client.games }
      assert_equal 500, error.status
      assert_instance_of Client::ApiError, error
    end
  end
end
