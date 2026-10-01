require "application_system_test_case"

class LocaleSwitcherTest < ApplicationSystemTestCase
  test "switching language updates the interface text" do
    # A previous test in this run may have resized the (shared) browser
    # window down to 375px, which would hide the desktop nav entirely.
    page.driver.browser.manage.window.resize_to(1400, 1400)
    sign_in_as(users(:elena))

    find("select#locale").select("English")
    assert_selector "a", text: "Inventory"

    find("select#locale").select("Français")
    assert_selector "a", text: "Inventaire"
  end

  # spec §12 "Responsive... 375 px" + "Localizzazione... nessuna stringa
  # hard-coded": every supported language must render the dashboard at the
  # spec's own minimum width without the page spilling sideways (a common
  # symptom of a translation running noticeably longer than its source).
  test "every supported language renders the dashboard without horizontal overflow at 375px width" do
    page.driver.browser.manage.window.resize_to(375, 800)
    sign_in_as(users(:elena))

    %w[it en fr es de].each do |locale|
      users(:elena).update!(locale: locale)
      visit root_path

      overflow = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth + 1")
      assert_not overflow, "the dashboard overflows horizontally at 375px in locale '#{locale}'"
    end
  end
end
