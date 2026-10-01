require "application_system_test_case"

# UX polish tranche: dynamic nested-form lines (Stimulus nested-form
# controller) and the blueprint autocomplete driven entirely from the
# keyboard (arrows + enter), spec §6.2 US-2.1.
class PurchasesDynamicLinesTest < ApplicationSystemTestCase
  test "picking a blueprint via keyboard fills the line and the purchase saves" do
    user = users(:elena)
    sign_in_as(user)
    t = ->(key) { I18n.with_locale(user.locale) { I18n.t(key) } }

    visit new_purchase_path

    select channels(:acme_fair).name, from: "purchase_channel_id"
    fill_in "purchase_title", with: "Fiera di prova"
    fill_in "purchase_currency", with: "EUR"

    first_line = all("[data-nested-form-target='item']").first
    within first_line do
      query = find("input[data-purchase-line-search-target='query']")
      query.fill_in with: "Teferi"

      assert_selector "[data-purchase-line-search-target='results'] button", wait: 10
      press_key(query, "ArrowDown")
      press_key(query, "Enter")

      assert_field "purchase_purchase_lines_attributes_0_description", with: ct_blueprints(:teferi).name
      fill_in "purchase_purchase_lines_attributes_0_quantity", with: 1
      # Elena's locale is Italian - money fields expect comma-decimal input.
      js_fill_in("purchase_purchase_lines_attributes_0_unit_price", with: "10,00")
    end

    js_click(t.call("purchases.form.submit"))

    assert_text "Fiera di prova"
    assert_text ct_blueprints(:teferi).name
  end

  test "adding and removing a line updates the form without a page reload" do
    user = users(:elena)
    sign_in_as(user)
    t = ->(key) { I18n.with_locale(user.locale) { I18n.t(key) } }

    visit new_purchase_path
    assert_selector "[data-nested-form-target='item']", count: 1

    js_click(t.call("purchases.form.add_line"))
    assert_selector "[data-nested-form-target='item']", count: 2
    assert_current_path new_purchase_path

    within all("[data-nested-form-target='item']").last do
      js_click(t.call("purchases.form.remove_line"))
    end
    assert_selector "[data-nested-form-target='item']:not([hidden])", count: 1
    assert_current_path new_purchase_path
  end
end
