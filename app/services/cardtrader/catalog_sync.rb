module Cardtrader
  # Upserts the public CardTrader catalog (games, categories, expansions,
  # and - per expansion - blueprints) into the local ct_* tables (spec §4.3,
  # §9.6). Called by SyncCatalogJob/SyncExpansionBlueprintsJob rather than
  # containing job-scheduling logic itself (§2.5: no business logic in
  # callbacks, service objects instead).
  class CatalogSync
    BLUEPRINT_BATCH_SIZE = 1000

    def initialize(client: Client.new)
      @client = client
    end

    def sync_games!
      rows = client.games.map { |game| game_row(game) }
      CtGame.upsert_all(rows, unique_by: :ct_id, record_timestamps: true) if rows.present?
    end

    def sync_categories!
      rows = client.categories.map { |category| category_row(category) }
      CtCategory.upsert_all(rows, unique_by: :ct_id, record_timestamps: true) if rows.present?
    end

    # Upserts every expansion and marks the ones CardTrader no longer
    # returns as removed. Returns the ct_ids of expansions belonging to
    # enabled games, for the caller to fan blueprint sync jobs out over.
    def sync_expansions!
      remote = client.expansions
      remote_ids = remote.map { |expansion| expansion.fetch("id") }

      rows = remote.map { |expansion| expansion_row(expansion) }
      CtExpansion.upsert_all(rows, unique_by: :ct_id, record_timestamps: true) if rows.present?

      CtExpansion.where(removed_at: nil).where.not(ct_id: remote_ids).update_all(removed_at: Time.current)

      CtExpansion.active
                 .joins("INNER JOIN ct_games ON ct_games.ct_id = ct_expansions.ct_game_id")
                 .merge(CtGame.enabled)
                 .distinct
                 .pluck(:ct_id)
    end

    # ct_expansion_id nil syncs blueprints with no expansion (client sends
    # the literal string "null", §9.6). Returns [upserted_count, removed_count].
    def sync_blueprints_for_expansion!(ct_expansion_id)
      remote = client.blueprints_export(expansion_id: ct_expansion_id.nil? ? "null" : ct_expansion_id)

      upserted = 0
      remote.each_slice(BLUEPRINT_BATCH_SIZE) do |batch|
        rows = batch.map { |blueprint| blueprint_row(blueprint) }
        CtBlueprint.upsert_all(rows, unique_by: :ct_id, record_timestamps: true)
        CtBlueprint.recompute_search_text!(rows.map { |row| row[:ct_id] })
        upserted += rows.size
      end

      remote_ids = remote.map { |blueprint| blueprint.fetch("id") }
      removed_scope = CtBlueprint.where(ct_expansion_id: ct_expansion_id, removed_at: nil)
      removed_scope = removed_scope.where.not(ct_id: remote_ids) if remote_ids.present?
      removed_count = removed_scope.update_all(removed_at: Time.current)

      [ upserted, removed_count ]
    end

    private

    attr_reader :client

    def game_row(game)
      {
        ct_id: game.fetch("id"),
        name: game.fetch("name"),
        display_name: game["display_name"],
        synced_at: Time.current
      }
    end

    def category_row(category)
      {
        ct_id: category.fetch("id"),
        ct_game_id: category.fetch("game_id"),
        name: category.fetch("name"),
        properties: category["properties"] || {},
        synced_at: Time.current
      }
    end

    def expansion_row(expansion)
      {
        ct_id: expansion.fetch("id"),
        ct_game_id: expansion.fetch("game_id"),
        code: expansion["code"],
        name: expansion.fetch("name"),
        synced_at: Time.current
      }
    end

    def blueprint_row(blueprint)
      fixed_properties = blueprint["fixed_properties"] || {}

      {
        ct_id: blueprint.fetch("id"),
        name: blueprint.fetch("name"),
        version: blueprint["version"],
        ct_game_id: blueprint.fetch("game_id"),
        ct_category_id: blueprint.fetch("category_id"),
        ct_expansion_id: blueprint["expansion_id"],
        image_url: blueprint["image_url"],
        editable_properties: blueprint["editable_properties"] || {},
        fixed_properties: fixed_properties,
        collector_number: extract_fixed_property(fixed_properties, "collector_number"),
        rarity: extract_fixed_property(fixed_properties, "rarity"),
        scryfall_id: blueprint["scryfall_id"],
        card_market_ids: Array(blueprint["card_market_ids"]).map(&:to_i),
        tcg_player_id: blueprint["tcg_player_id"],
        synced_at: Time.current
      }
    end

    # fixed_properties' exact shape isn't nailed down in the reference docs
    # we could verify against - handles both a plain {"collector_number" =>
    # "221"} hash and an array of {"name"/"key" => ..., "value" => ...}
    # property objects (the shape editable_properties is documented to use).
    def extract_fixed_property(fixed_properties, key)
      case fixed_properties
      when Hash
        fixed_properties[key] || fixed_properties[key.to_sym]
      when Array
        entry = fixed_properties.find { |p| p.is_a?(Hash) && (p["name"] == key || p["key"] == key) }
        entry && (entry["value"] || entry["values"])
      end
    end
  end
end
