require "test_helper"

class CtCategoryTest < ActiveSupport::TestCase
  test "valid with ct_id, ct_game_id and name" do
    category = CtCategory.new(ct_id: 99, ct_game_id: ct_games(:magic).ct_id, name: "Magic Sealed")
    assert category.valid?
  end

  test "requires a unique ct_id" do
    duplicate = CtCategory.new(ct_id: ct_categories(:magic_single).ct_id, ct_game_id: 1, name: "dup")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ct_id], "has already been taken"
  end

  test "belongs_to ct_game via the external ct_id, not the local primary key" do
    category = ct_categories(:magic_single)
    assert_equal ct_games(:magic), category.ct_game
  end

  test "requires a resolvable ct_game" do
    category = CtCategory.new(ct_id: 99, ct_game_id: 999_999, name: "Orphan")
    assert_not category.valid?
    assert_includes category.errors[:ct_game], "must exist"
  end
end
