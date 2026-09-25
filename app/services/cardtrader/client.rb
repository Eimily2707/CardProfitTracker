require "net/http"
require "json"

module Cardtrader
  # Thin wrapper around CardTrader API v2 (https://api.cardtrader.com/api/v2).
  # Requires an auth token, either in Rails credentials:
  #   cardtrader:
  #     api_token: xxxxx
  # or in the CARDTRADER_API_TOKEN environment variable.
  class Client
    class ApiError < StandardError; end

    BASE_URL = "https://api.cardtrader.com/api/v2".freeze

    def initialize(token: nil)
      @token = token || self.class.token
    end

    def self.token
      Rails.application.credentials.dig(:cardtrader, :api_token) || ENV["CARDTRADER_API_TOKEN"]
    end

    def games
      get("/games")
    end

    def expansions(game_id: nil)
      get("/expansions", game_id ? { game_id: game_id } : {})
    end

    def blueprints_export(expansion_id:)
      get("/blueprints/export", expansion_id: expansion_id)
    end

    private

    def get(path, params = {})
      raise ApiError, "CARDTRADER_API_TOKEN non configurato" if @token.blank?

      uri = URI.join(BASE_URL, path)
      uri.query = URI.encode_www_form(params) if params.present?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise ApiError, "CardTrader API error (#{response.code}): #{response.body}"
      end

      JSON.parse(response.body)
    end
  end
end
