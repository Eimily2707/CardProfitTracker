require "test_helper"

class CtExpansionTest < ActiveSupport::TestCase
  test "valid with ct_id, ct_game_id and name" do
    expansion = CtExpansion.new(ct_id: 99, ct_game_id: ct_games(:magic).ct_id, name: "New Set")
    assert expansion.valid?
  end

  test "defaults export_status to ok" do
    assert_equal "ok", CtExpansion.new.export_status
  end

  test "rejects an unsupported export_status" do
    expansion = CtExpansion.new(ct_id: 99, ct_game_id: 1, name: "New Set", export_status: "weird")
    assert_not expansion.valid?
    assert_includes expansion.errors[:export_status], "is not included in the list"
  end

  test "active scope excludes removed expansions" do
    assert_includes CtExpansion.active, ct_expansions(:war_of_the_spark)
    assert_not_includes CtExpansion.active, ct_expansions(:removed_expansion)
  end
end
