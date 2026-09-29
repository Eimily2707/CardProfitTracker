require "test_helper"

class CtGameTest < ActiveSupport::TestCase
  test "valid with ct_id and name" do
    game = CtGame.new(ct_id: 99, name: "yugioh")
    assert game.valid?
  end

  test "requires a unique ct_id" do
    duplicate = CtGame.new(ct_id: ct_games(:magic).ct_id, name: "duplicate")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ct_id], "has already been taken"
  end

  test "requires a name" do
    game = CtGame.new(ct_id: 99)
    assert_not game.valid?
    assert_includes game.errors[:name], "can't be blank"
  end

  test "defaults to enabled" do
    assert CtGame.new(ct_id: 99, name: "yugioh").enabled?
  end

  test "enabled scope only returns enabled games" do
    assert_includes CtGame.enabled, ct_games(:magic)
    assert_not_includes CtGame.enabled, ct_games(:pokemon)
  end
end
