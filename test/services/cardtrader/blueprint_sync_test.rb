require "test_helper"

module Cardtrader
  class BlueprintSyncTest < ActiveSupport::TestCase
    setup do
      @client = Client.new(token: "test-token")
    end

    test "downloads expansions and upserts their blueprints locally" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: [ { "id" => 10, "game_id" => 1, "name" => "War of the Spark" } ].to_json)

      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => "10" })
        .to_return(status: 200, body: [
          {
            "id" => 701, "name" => "Jace, the Mind Sculptor", "game_id" => 1, "category_id" => 1,
            "image_url" => "https://example.com/jace.jpg", "scryfall_id" => "abc123",
            "card_market_ids" => [ 111, 222 ]
          },
          {
            "id" => 702, "name" => "Narset, Parter of Veils", "game_id" => 1, "category_id" => 1,
            "image_url" => "https://example.com/narset.jpg", "scryfall_id" => "def456",
            "card_market_ids" => []
          }
        ].to_json)

      assert_difference("CardtraderBlueprint.count", 2) do
        Cardtrader::BlueprintSync.new(client: @client).call
      end

      blueprint = CardtraderBlueprint.find_by(cardtrader_id: 701)
      assert_equal "Jace, the Mind Sculptor", blueprint.name
      assert_equal "War of the Spark", blueprint.expansion_name
      assert_equal "111", blueprint.cardmarket_id

      narset = CardtraderBlueprint.find_by(cardtrader_id: 702)
      assert_nil narset.cardmarket_id
    end

    test "upserts without creating duplicates when a blueprint already exists" do
      existing = cardtrader_blueprints(:teferi_blueprint)

      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: [ { "id" => 20, "game_id" => existing.game_id, "name" => existing.expansion_name } ].to_json)

      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => "20" })
        .to_return(status: 200, body: [
          {
            "id" => existing.cardtrader_id, "name" => "Teferi, Time Raveler (updated)",
            "game_id" => existing.game_id, "category_id" => existing.category_id
          }
        ].to_json)

      assert_no_difference("CardtraderBlueprint.count") do
        Cardtrader::BlueprintSync.new(client: @client).call
      end

      assert_equal "Teferi, Time Raveler (updated)", existing.reload.name
    end

    test "scopes the expansions lookup to a single game when game_id is given" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
             .with(query: { "game_id" => "1" })
             .to_return(status: 200, body: "[]")

      Cardtrader::BlueprintSync.new(client: @client, game_id: 1).call

      assert_requested stub
    end

    test "skips an expansion whose blueprint export fails without raising or upserting" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: [ { "id" => 30, "game_id" => 1, "name" => "Broken Expansion" } ].to_json)

      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => "30" })
        .to_return(status: 500, body: "boom")

      assert_no_difference("CardtraderBlueprint.count") do
        assert_nothing_raised { Cardtrader::BlueprintSync.new(client: @client).call }
      end
    end
  end
end
