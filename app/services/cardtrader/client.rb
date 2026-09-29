require "net/http"
require "json"

module Cardtrader
  # Thin wrapper around CardTrader API v2 (https://api.cardtrader.com/api/v2).
  # Requires an auth token, either in Rails credentials:
  #   cardtrader:
  #     api_token: xxxxx
  # or in the CARDTRADER_API_TOKEN environment variable.
  #
  # Raises a distinct error subclass per failure kind so callers (in
  # particular Cardtrader::ApplicationJob's retry_on/discard_on policies) can
  # tell a transient problem (rate limit, network blip) from a permanent one
  # (bad token, unknown resource) without parsing message strings.
  class Client
    class ApiError < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        super(message)
        @status = status
      end
    end

    # 429 Too Many Requests, or the connection/rate-limit reset mid-flight: worth retrying.
    class RateLimitError < ApiError; end
    # Network-level failure (timeout, connection refused/reset, DNS): worth retrying.
    class ConnectionError < ApiError; end
    # 401 Unauthorized, or no token configured at all: retrying changes nothing.
    class AuthenticationError < ApiError; end
    # 404 Not Found: the resource (order, expansion...) doesn't exist; retrying changes nothing.
    class NotFoundError < ApiError; end

    NETWORK_ERRORS = [
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT,
      Net::OpenTimeout, Net::ReadTimeout, SocketError, EOFError
    ].freeze

    BASE_URL = "https://api.cardtrader.com/api/v2".freeze

    # §9.5: 10s to open a connection, 30s to read by default; individual
    # calls (blueprints/export) override read_timeout for known-slow exports.
    OPEN_TIMEOUT = 10
    DEFAULT_READ_TIMEOUT = 30

    def initialize(token: nil)
      @token = token || self.class.token
    end

    def self.token
      Rails.application.credentials.dig(:cardtrader, :api_token) || ENV["CARDTRADER_API_TOKEN"]
    end

    def games
      get("/games")
    end

    def categories(game_id: nil)
      get("/categories", game_id ? { game_id: game_id } : {})
    end

    def expansions(game_id: nil)
      get("/expansions", game_id ? { game_id: game_id } : {})
    end

    # expansion_id also accepts the literal string "null" for blueprints
    # with no expansion (§9.6) - never send category_id, CardTrader always
    # 404s on that combination and expects per-expansion export + local filtering.
    def blueprints_export(expansion_id:)
      get("/blueprints/export", { expansion_id: expansion_id }, read_timeout: 180)
    end

    def orders(order_as: "buyer", limit: 20, page: 1)
      get("/orders", { order_as: order_as, limit: limit, page: page })
    end

    def order(id)
      get("/orders/#{id}")
    end

    private

    def get(path, params = {}, read_timeout: DEFAULT_READ_TIMEOUT)
      if @token.blank?
        raise AuthenticationError.new("CARDTRADER_API_TOKEN non configurato")
      end

      # URI.join(BASE_URL, path) would treat a leading "/" in path as absolute
      # and drop the "/api/v2" prefix, so build the URI from a plain concatenation.
      uri = URI("#{BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params) if params.present?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@token}"
      request["Accept"] = "application/json"

      response =
        begin
          Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout) do |http|
            http.request(request)
          end
        rescue *NETWORK_ERRORS => e
          raise ConnectionError, "Errore di connessione a CardTrader: #{e.message}"
        end

      handle_response(response)
    end

    def handle_response(response)
      case response
      when Net::HTTPSuccess
        JSON.parse(response.body)
      when Net::HTTPTooManyRequests
        raise RateLimitError.new("CardTrader API error (429): #{response.body}", status: 429)
      when Net::HTTPUnauthorized
        raise AuthenticationError.new("CardTrader API error (401): #{response.body}", status: 401)
      when Net::HTTPNotFound
        raise NotFoundError.new("CardTrader API error (404): #{response.body}", status: 404)
      else
        raise ApiError.new("CardTrader API error (#{response.code}): #{response.body}", status: response.code.to_i)
      end
    end
  end
end
