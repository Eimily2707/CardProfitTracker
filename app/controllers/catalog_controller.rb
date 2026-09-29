# Catalog browse page (spec §6.1, US-1.2): filter dropdowns are populated
# here; the actual search/filter results are fetched live by Catalog::SearchController.
class CatalogController < ApplicationController
  def index
    @games = CtGame.enabled.order(:name)
    @categories = CtCategory.order(:name)
    @expansions = CtExpansion.active.order(:name)
  end
end
