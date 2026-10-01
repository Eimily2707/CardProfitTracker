require "test_helper"

class StatusBadgeHelperTest < ActionView::TestCase
  test "renders the translated label with the mapped color" do
    I18n.with_locale(:it) do
      badge = status_badge("received", scope: "purchase.status")

      assert_match "Ricevuto", badge
      assert_match "bg-green-100", badge
    end
  end

  test "falls back to gray for an unmapped status" do
    badge = status_badge("bogus", scope: "purchase.status")

    assert_match "bg-gray-100", badge
  end
end
