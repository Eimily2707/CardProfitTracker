module Cardtrader
  # Pulls the CardTrader blueprint catalog into the local `cardtrader_blueprints`
  # table via upsert_all, so search/autocomplete never has to hit the live API
  # (and never risks its rate limit) once synced.
  #
  # CardTrader's /blueprints/export endpoint requires an expansion_id, so this
  # walks /expansions (optionally scoped to one game) and exports each one.
  class BlueprintSync
    REQUEST_INTERVAL = 0.1 # seconds between blueprint export calls, to stay well under the 200 req/10s API limit

    def initialize(client: Client.new, game_id: nil, logger: Rails.logger)
      @client = client
      @game_id = game_id
      @logger = logger
    end

    def call
      total_upserted = 0

      expansions.each do |expansion|
        rows = blueprint_rows_for(expansion)
        total_upserted += upsert(rows) if rows.present?
        sleep(REQUEST_INTERVAL)
      end

      logger.info("[Cardtrader::BlueprintSync] Done. Upserted #{total_upserted} blueprints across #{expansions.size} expansions.")
      total_upserted
    end

    private

    attr_reader :client, :game_id, :logger

    def expansions
      @expansions ||= client.expansions(game_id: game_id)
    end

    def blueprint_rows_for(expansion)
      blueprints = client.blueprints_export(expansion_id: expansion.fetch("id"))

      blueprints.map do |blueprint|
        {
          cardtrader_id: blueprint.fetch("id"),
          name: blueprint.fetch("name"),
          expansion_name: expansion["name"],
          game_id: blueprint["game_id"],
          category_id: blueprint["category_id"],
          image_url: blueprint["image_url"],
          scryfall_id: blueprint["scryfall_id"],
          cardmarket_id: Array(blueprint["card_market_ids"]).first&.to_s
        }
      end
    rescue Client::ApiError => e
      logger.warn("[Cardtrader::BlueprintSync] Skipping expansion #{expansion['id']} (#{expansion['name']}): #{e.message}")
      []
    end

    def upsert(rows)
      result = CardtraderBlueprint.upsert_all(
        rows,
        unique_by: :cardtrader_id,
        record_timestamps: true
      )
      result.length
    end
  end
end
