require "application_system_test_case"

# spec §12 "Responsive... 375 px": the desktop nav row would overflow at
# that width, so it collapses behind a hamburger toggle instead.
class MobileMenuTest < ApplicationSystemTestCase
  test "the hamburger toggle reveals the nav panel and navigates" do
    resize_viewport_to(375, 800)
    user = users(:elena)
    sign_in_as(user)

    assert_no_selector "#mobile-nav-panel:not([hidden])"

    # Selenium's coordinate-based native click intermittently never reaches
    # headless Chrome in CI (see js_click) - affects this hamburger
    # toggle/nav link exactly like it affects buttons elsewhere.
    js_click(find("button[aria-controls='mobile-nav-panel']"))
    assert_selector "#mobile-nav-panel:not([hidden])"

    inventory_title = I18n.with_locale(user.locale) { I18n.t("inventory_items.index.title") }
    within "#mobile-nav-panel" do
      js_click(inventory_title)
    end

    assert_selector "h1", text: inventory_title
  end
end
