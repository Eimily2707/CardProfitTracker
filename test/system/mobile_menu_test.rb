require "application_system_test_case"

# spec §12 "Responsive... 375 px": the desktop nav row would overflow at
# that width, so it collapses behind a hamburger toggle instead.
class MobileMenuTest < ApplicationSystemTestCase
  test "the hamburger toggle reveals the nav panel and navigates" do
    page.driver.browser.manage.window.resize_to(375, 800)
    user = users(:elena)
    sign_in_as(user)

    assert_no_selector "#mobile-nav-panel:not([hidden])"

    find("button[aria-controls='mobile-nav-panel']").click
    assert_selector "#mobile-nav-panel:not([hidden])"

    inventory_title = I18n.with_locale(user.locale) { I18n.t("inventory_items.index.title") }
    within "#mobile-nav-panel" do
      click_on inventory_title
    end

    assert_selector "h1", text: inventory_title
  end
end
