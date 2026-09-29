require "test_helper"

module Cardtrader
  class CatalogSyncTest < ActiveSupport::TestCase
    setup do
      @sync = CatalogSync.new(client: Client.new(token: "test-token"))
    end

    test "sync_games! upserts games without creating duplicates" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/games")
        .to_return(status: 200, body: [
          { "id" => ct_games(:magic).ct_id, "name" => "magic", "display_name" => "Magic: The Gathering (updated)" },
          { "id" => 99, "name" => "yugioh", "display_name" => "Yu-Gi-Oh!" }
        ].to_json)

      assert_difference("CtGame.count", 1) { @sync.sync_games! }

      assert_equal "Magic: The Gathering (updated)", ct_games(:magic).reload.display_name
      assert_not_nil CtGame.find_by(ct_id: 99)
    end

    test "sync_categories! upserts categories" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/categories")
        .to_return(status: 200, body: [
          { "id" => 99, "game_id" => 1, "name" => "Magic Sealed", "properties" => [ "foil" ] }
        ].to_json)

      assert_difference("CtCategory.count", 1) { @sync.sync_categories! }

      category = CtCategory.find_by(ct_id: 99)
      assert_equal "Magic Sealed", category.name
      assert_equal [ "foil" ], category.properties
    end

    test "sync_expansions! upserts expansions, marks missing ones removed, and returns enabled-game expansion ids" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: [
          { "id" => ct_expansions(:war_of_the_spark).ct_id, "game_id" => 1, "code" => "WAR", "name" => "War of the Spark" },
          { "id" => 30, "game_id" => 2, "code" => "SVI", "name" => "Scarlet Violet" }
        ].to_json)

      enabled_ids = @sync.sync_expansions!

      assert_includes enabled_ids, ct_expansions(:war_of_the_spark).ct_id
      # game_id 2 (pokemon) is disabled in fixtures, so its expansion shouldn't be a sync target.
      assert_not_includes enabled_ids, 30
      assert CtExpansion.exists?(ct_id: 30)
    end

    test "sync_expansions! marks an expansion CardTrader no longer returns as removed" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions")
        .to_return(status: 200, body: "[]")

      @sync.sync_expansions!

      assert_not_nil ct_expansions(:war_of_the_spark).reload.removed_at
    end

    test "sync_expansions! does not re-flag an already-removed expansion" do
      original_removed_at = ct_expansions(:removed_expansion).removed_at

      stub_request(:get, "https://api.cardtrader.com/api/v2/expansions").to_return(status: 200, body: "[]")
      @sync.sync_expansions!

      assert_equal original_removed_at.to_i, ct_expansions(:removed_expansion).reload.removed_at.to_i
    end

    test "sync_blueprints_for_expansion! upserts blueprints, computes search_text and collector_number" do
      # A fresh expansion with no pre-existing blueprints, so "removed" only
      # reflects this call's own upsert, not fixture blueprints from a
      # shared expansion getting correctly-but-confusingly marked removed.
      expansion = CtExpansion.create!(ct_id: 40, ct_game_id: 1, code: "NEO", name: "Kamigawa: Neon Dynasty")

      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => expansion.ct_id.to_s })
        .to_return(status: 200, body: [
          {
            "id" => 601, "name" => "Jace, the Mind Sculptor", "game_id" => 1, "category_id" => 1,
            "expansion_id" => expansion.ct_id,
            "fixed_properties" => { "collector_number" => "45", "rarity" => "mythic" },
            "card_market_ids" => [ 111, 222 ]
          }
        ].to_json)

      upserted, removed = @sync.sync_blueprints_for_expansion!(expansion.ct_id)

      assert_equal 1, upserted
      assert_equal 0, removed

      blueprint = CtBlueprint.find_by(ct_id: 601)
      assert_equal "45", blueprint.collector_number
      assert_equal "mythic", blueprint.rarity
      assert_equal [ 111, 222 ], blueprint.card_market_ids
      assert_match "jace", blueprint.search_text
    end

    test "sync_blueprints_for_expansion! marks blueprints CardTrader no longer returns as removed" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
        .with(query: { "expansion_id" => ct_expansions(:war_of_the_spark).ct_id.to_s })
        .to_return(status: 200, body: [
          { "id" => ct_blueprints(:teferi).ct_id, "name" => "Teferi, Time Raveler", "game_id" => 1, "category_id" => 1 }
        ].to_json)

      _upserted, removed = @sync.sync_blueprints_for_expansion!(ct_expansions(:war_of_the_spark).ct_id)

      assert_equal 1, removed
      assert_not_nil ct_blueprints(:narset).reload.removed_at
      assert_nil ct_blueprints(:teferi).reload.removed_at
    end

    test "sync_blueprints_for_expansion! accepts nil for blueprints with no expansion" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/blueprints/export")
             .with(query: { "expansion_id" => "null" })
             .to_return(status: 200, body: "[]")

      @sync.sync_blueprints_for_expansion!(nil)

      assert_requested stub
    end
  end
end
