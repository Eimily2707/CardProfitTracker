require "test_helper"

class CatalogControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get catalog_url
    assert_redirected_to new_session_url
  end

  test "shows the browse page with filter options" do
    sign_in_as(users(:elena))

    get catalog_url

    assert_response :success
    assert_select "option", text: "Magic: The Gathering"
    assert_select "option", text: "War of the Spark"
    assert_select "option", text: "Magic Single"
  end

  test "does not list disabled games as filter options" do
    sign_in_as(users(:elena))

    get catalog_url

    assert_response :success
    assert_select "option", text: "Pokémon", count: 0
  end
end
