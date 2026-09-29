# Live JSON endpoint backing the catalog browse page's autocomplete
# (spec §6.1, US-1.2). With a query it uses CtBlueprint.search (exact ->
# prefix -> trigram ranking); without one it just lists by the given filters,
# so picking a game/category/expansion alone still shows results.
module Catalog
  class SearchController < ApplicationController
    def index
      scope = params[:query].present? ? CtBlueprint.search(params[:query]) : CtBlueprint.active.order(:name).limit(30)

      blueprints = scope
        .in_game(params[:ct_game_id])
        .in_category(params[:ct_category_id])
        .in_expansion(params[:ct_expansion_id])
        .includes(:ct_expansion, :ct_category)

      render json: blueprints.map { |blueprint| serialize(blueprint) }
    end

    private

    def serialize(blueprint)
      {
        ct_id: blueprint.ct_id,
        name: blueprint.name,
        version: blueprint.version,
        collector_number: blueprint.collector_number,
        rarity: blueprint.rarity,
        image_url: blueprint.image_url,
        category_name: blueprint.ct_category&.name,
        expansion_name: blueprint.ct_expansion&.name
      }
    end
  end
end
