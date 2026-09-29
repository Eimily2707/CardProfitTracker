require "test_helper"

class CtBlueprintTest < ActiveSupport::TestCase
  test "valid with ct_id, name, ct_game_id and ct_category_id" do
    blueprint = CtBlueprint.new(ct_id: 999, name: "Test Card", ct_game_id: 1, ct_category_id: 1)
    assert blueprint.valid?
  end

  test "ct_expansion_id is optional (blueprints with no expansion, §4.3)" do
    blueprint = CtBlueprint.new(ct_id: 999, name: "Test Card", ct_game_id: 1, ct_category_id: 1, ct_expansion_id: nil)
    assert blueprint.valid?
  end

  test "requires a unique ct_id" do
    duplicate = CtBlueprint.new(ct_id: ct_blueprints(:teferi).ct_id, name: "dup", ct_game_id: 1, ct_category_id: 1)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ct_id], "has already been taken"
  end

  test "computes search_text from name, version and expansion on save" do
    blueprint = CtBlueprint.create!(
      ct_id: 999, name: "Über Card", version: "Foil", ct_game_id: 1, ct_category_id: 1,
      ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id
    )

    assert_equal "uber card foil war of the spark war", blueprint.search_text
  end

  test "computes search_text without an expansion when there is none" do
    blueprint = CtBlueprint.create!(ct_id: 999, name: "Loose Card", ct_game_id: 1, ct_category_id: 1)
    assert_equal "loose card", blueprint.search_text
  end

  test "active scope excludes removed blueprints" do
    assert_includes CtBlueprint.active, ct_blueprints(:teferi)
    assert_not_includes CtBlueprint.active, ct_blueprints(:removed_blueprint)
  end

  test "in_expansion/in_category/in_game filter, or pass through when blank" do
    assert_includes CtBlueprint.in_expansion(ct_expansions(:war_of_the_spark).ct_id), ct_blueprints(:teferi)
    assert_equal CtBlueprint.count, CtBlueprint.in_expansion(nil).count

    assert_includes CtBlueprint.in_category(1), ct_blueprints(:teferi)
    assert_includes CtBlueprint.in_game(1), ct_blueprints(:teferi)
  end

  test "search finds an exact name match" do
    assert_includes CtBlueprint.search("Teferi, Time Raveler"), ct_blueprints(:teferi)
  end

  test "search finds a prefix match" do
    assert_includes CtBlueprint.search("tefer"), ct_blueprints(:teferi)
  end

  test "search tolerates a typo via trigram similarity" do
    assert_includes CtBlueprint.search("tiferi"), ct_blueprints(:teferi)
  end

  test "search treats % and _ literally, not as SQL LIKE wildcards" do
    assert_empty CtBlueprint.search("100%off")
    assert_empty CtBlueprint.search("te_eri")
  end

  test "search returns nothing for a query under 2 characters" do
    assert_empty CtBlueprint.search("t")
    assert_empty CtBlueprint.search("")
    assert_empty CtBlueprint.search(nil)
  end

  test "search excludes removed blueprints" do
    assert_not_includes CtBlueprint.search("removed card"), ct_blueprints(:removed_blueprint)
  end

  test "search ranks an exact match before a prefix match before a substring match" do
    exact = CtBlueprint.create!(ct_id: 991, name: "war", ct_game_id: 1, ct_category_id: 1)
    prefix = CtBlueprint.create!(ct_id: 992, name: "warden", ct_game_id: 1, ct_category_id: 1)

    results = CtBlueprint.search("war").to_a
    exact_index = results.index { |r| r.ct_id == exact.ct_id }
    prefix_index = results.index { |r| r.ct_id == prefix.ct_id }
    # teferi's search_text contains "war" mid-string ("... war of the spark war"), so it's neither exact nor a prefix match.
    substring_index = results.index { |r| r.ct_id == ct_blueprints(:teferi).ct_id }

    assert_equal 0, exact_index
    assert prefix_index < substring_index
  end

  test "search_by_collector_number finds an exact match" do
    assert_includes CtBlueprint.search_by_collector_number("221"), ct_blueprints(:teferi)
  end

  test "search_by_collector_number can be filtered by expansion" do
    other_expansion = CtExpansion.create!(ct_id: 20, ct_game_id: 1, name: "Other Set")

    assert_includes CtBlueprint.search_by_collector_number("221", ct_expansion_id: ct_expansions(:war_of_the_spark).ct_id), ct_blueprints(:teferi)
    assert_empty CtBlueprint.search_by_collector_number("221", ct_expansion_id: other_expansion.ct_id)
  end

  test "search_by_collector_number returns nothing for a blank number" do
    assert_empty CtBlueprint.search_by_collector_number(nil)
    assert_empty CtBlueprint.search_by_collector_number("")
  end

  test "recompute_search_text! bulk-updates search_text for the given ct_ids" do
    CtBlueprint.where(ct_id: ct_blueprints(:teferi).ct_id).update_all(search_text: nil)
    assert_nil ct_blueprints(:teferi).reload.search_text

    CtBlueprint.recompute_search_text!([ ct_blueprints(:teferi).ct_id ])

    assert_equal "teferi, time raveler war of the spark war", ct_blueprints(:teferi).reload.search_text
  end

  test "recompute_search_text! handles blueprints with no expansion" do
    blueprint = CtBlueprint.create!(ct_id: 993, name: "No Expansion Card", ct_game_id: 1, ct_category_id: 1)
    CtBlueprint.where(ct_id: 993).update_all(search_text: nil)

    CtBlueprint.recompute_search_text!([ 993 ])

    assert_equal "no expansion card", blueprint.reload.search_text
  end

  test "recompute_search_text! does nothing for a blank list" do
    assert_nothing_raised { CtBlueprint.recompute_search_text!([]) }
  end
end
