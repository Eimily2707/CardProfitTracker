require "application_system_test_case"

# spec §6.1 US-1.2: live catalog search, fetched via JS (no Turbo Frame/
# full-page submit) - the URL never changes while results update.
class CatalogSearchTest < ApplicationSystemTestCase
  test "typing a query live-filters results without a page reload" do
    sign_in_as(users(:elena))
    visit catalog_path

    fill_in "catalog_query", with: "Teferi"

    assert_selector "[data-catalog-search-target='results'] p", text: ct_blueprints(:teferi).name, wait: 5
    assert_no_selector "[data-catalog-search-target='results'] p", text: ct_blueprints(:narset).name
    assert_current_path catalog_path
  end
end
