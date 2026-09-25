require "test_helper"

class CardtraderBlueprintTest < ActiveSupport::TestCase
  test "valid with cardtrader_id and name" do
    blueprint = CardtraderBlueprint.new(cardtrader_id: 999_999, name: "Test Card")
    assert blueprint.valid?
  end

  test "requires a cardtrader_id" do
    blueprint = CardtraderBlueprint.new(name: "Test Card")
    assert_not blueprint.valid?
    assert_includes blueprint.errors[:cardtrader_id], "can't be blank"
  end

  test "requires a unique cardtrader_id" do
    duplicate = CardtraderBlueprint.new(cardtrader_id: cardtrader_blueprints(:elsa_blueprint).cardtrader_id, name: "Duplicate Elsa")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cardtrader_id], "has already been taken"
  end

  test "requires a name" do
    blueprint = CardtraderBlueprint.new(cardtrader_id: 999_999)
    assert_not blueprint.valid?
    assert_includes blueprint.errors[:name], "can't be blank"
  end

  test "search finds blueprints by a partial name match" do
    results = CardtraderBlueprint.search("Snow Queen")
    assert_includes results, cardtrader_blueprints(:elsa_blueprint)
  end

  test "search is case-insensitive" do
    results = CardtraderBlueprint.search("mickey mouse")
    assert_includes results, cardtrader_blueprints(:mickey_blueprint)
  end

  test "search excludes non-matching blueprints" do
    results = CardtraderBlueprint.search("elsa")
    assert_not_includes results, cardtrader_blueprints(:teferi_blueprint)
    assert_not_includes results, cardtrader_blueprints(:mickey_blueprint)
  end

  test "search returns no results for an unmatched query" do
    assert_empty CardtraderBlueprint.search("this card does not exist")
  end
end
