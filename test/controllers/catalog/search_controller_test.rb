require "test_helper"

module Catalog
  class SearchControllerTest < ActionDispatch::IntegrationTest
    test "requires authentication" do
      get catalog_search_url

      assert_redirected_to new_session_url
    end

    test "finds a blueprint by fuzzy query" do
      sign_in_as(users(:elena))

      get catalog_search_url, params: { query: "teferi" }, as: :json

      assert_response :success
      names = JSON.parse(response.body).map { |r| r["name"] }
      assert_includes names, "Teferi, Time Raveler"
      assert_not_includes names, "Narset, Parter of Veils"
    end

    test "excludes removed blueprints" do
      sign_in_as(users(:elena))

      get catalog_search_url, params: { query: "removed" }, as: :json

      assert_response :success
      assert_equal [], JSON.parse(response.body)
    end

    test "lists blueprints by filters alone, with no query" do
      sign_in_as(users(:elena))

      get catalog_search_url, params: { ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id }, as: :json

      assert_response :success
      names = JSON.parse(response.body).map { |r| r["name"] }
      assert_includes names, "Teferi, Time Raveler"
      assert_includes names, "Narset, Parter of Veils"
    end

    test "combines a query with filters" do
      sign_in_as(users(:elena))

      get catalog_search_url, params: {
        query: "teferi",
        ct_game_id: ct_games(:magic).ct_id,
        ct_category_id: ct_categories(:magic_single).ct_id
      }, as: :json

      assert_response :success
      names = JSON.parse(response.body).map { |r| r["name"] }
      assert_equal [ "Teferi, Time Raveler" ], names
    end
  end
end
