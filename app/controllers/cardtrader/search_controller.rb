module Cardtrader
  # Local autocomplete over the synced CardtraderBlueprint catalog (see
  # `cardtrader:sync_blueprints`), so typing in the unboxing search box never
  # calls the live CardTrader API and never risks its rate limit.
  class SearchController < ApplicationController
    RESULTS_LIMIT = 15

    def index
      query = params[:query].to_s.strip

      results =
        if query.blank?
          []
        else
          CardtraderBlueprint.search(query).limit(RESULTS_LIMIT)
        end

      render json: results.as_json(only: %i[cardtrader_id name expansion_name image_url])
    end
  end
end
