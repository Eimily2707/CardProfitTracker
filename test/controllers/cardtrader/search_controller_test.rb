require "test_helper"

module Cardtrader
  class SearchControllerTest < ActionDispatch::IntegrationTest
    test "returns matching blueprints as json" do
      get cardtrader_search_url(query: "Snow Queen")

      assert_response :success

      json = JSON.parse(response.body)
      assert_equal 1, json.length
      assert_equal cardtrader_blueprints(:elsa_blueprint).cardtrader_id, json.first["cardtrader_id"]
      assert_equal "Elsa - Snow Queen", json.first["name"]
      assert_equal "Rise of the Floodborn", json.first["expansion_name"]
      assert_equal %w[cardtrader_id name expansion_name image_url category_id], json.first.keys
      assert_equal cardtrader_blueprints(:elsa_blueprint).category_id, json.first["category_id"]
    end

    test "search is case-insensitive" do
      get cardtrader_search_url(query: "MICKEY")

      json = JSON.parse(response.body)
      assert_equal 1, json.length
      assert_equal cardtrader_blueprints(:mickey_blueprint).cardtrader_id, json.first["cardtrader_id"]
    end

    test "returns an empty array for a blank query" do
      get cardtrader_search_url(query: "")
      assert_equal [], JSON.parse(response.body)
    end

    test "returns an empty array when nothing matches" do
      get cardtrader_search_url(query: "nonexistent-card-zzz")
      assert_equal [], JSON.parse(response.body)
    end

    test "limits results to 15" do
      20.times { |i| CardtraderBlueprint.create!(cardtrader_id: 800_000 + i, name: "Bulk Test Card #{i}") }

      get cardtrader_search_url(query: "Bulk Test Card")

      json = JSON.parse(response.body)
      assert_equal 15, json.length
    end
  end
end
