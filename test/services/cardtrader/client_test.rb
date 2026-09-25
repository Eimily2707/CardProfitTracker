require "test_helper"

module Cardtrader
  class ClientTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(token: "test-token")
    end

    test "raises without an API token configured" do
      client = Client.new(token: nil)
      assert_raises(Client::ApiError) { client.games }
    end

    test "sends the bearer token and accept header on every request" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/games")
             .with(headers: { "Authorization" => "Bearer test-token", "Accept" => "application/json" })
             .to_return(status: 200, body: [ { "id" => 1, "name" => "Magic: The Gathering" } ].to_json)

      result = @client.games

      assert_requested stub
      assert_equal [ { "id" => 1, "name" => "Magic: The Gathering" } ], result
    end

    test "expansions includes the game_id filter when given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
             .with(query: { "game_id" => "1" })
             .to_return(status: 200, body: [ { "id" => 10, "game_id" => 1, "name" => "War of the Spark" } ].to_json)

      result = @client.expansions(game_id: 1)

      assert_requested stub
      assert_equal 1, result.length
    end

    test "expansions omits the game_id filter when not given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
             .to_return(status: 200, body: "[]")

      @client.expansions

      assert_requested stub
    end

    test "blueprints_export sends the required expansion_id parameter" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
             .with(query: { "expansion_id" => "10" })
             .to_return(status: 200, body: [ { "id" => 501, "name" => "Elsa - Snow Queen" } ].to_json)

      result = @client.blueprints_export(expansion_id: 10)

      assert_requested stub
      assert_equal "Elsa - Snow Queen", result.first["name"]
    end

    test "orders defaults to the buyer role and default pagination" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
             .with(query: { "order_as" => "buyer", "limit" => "20", "page" => "1" })
             .to_return(status: 200, body: [ { "id" => 1 } ].to_json)

      result = @client.orders

      assert_requested stub
      assert_equal 1, result.length
    end

    test "orders forwards custom pagination and role" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
             .with(query: { "order_as" => "seller", "limit" => "5", "page" => "2" })
             .to_return(status: 200, body: "[]")

      @client.orders(order_as: "seller", limit: 5, page: 2)

      assert_requested stub
    end

    test "order fetches a single order by id" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders/42")
             .to_return(status: 200, body: { "id" => 42, "state" => "paid" }.to_json)

      result = @client.order(42)

      assert_requested stub
      assert_equal "paid", result["state"]
    end

    test "raises an ApiError on a non-2xx response" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 429, body: '{"error":"Too many requests: max 200 requests per 10 seconds"}')

      error = assert_raises(Client::ApiError) { @client.games }
      assert_match "429", error.message
    end
  end
end
