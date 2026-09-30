require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get sales_report_url
    assert_redirected_to new_session_url
  end

  test "downloads the sales CSV" do
    sign_in_as(users(:elena))

    get sales_report_url

    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "downloads the inventory valuation CSV" do
    sign_in_as(users(:elena))

    get inventory_report_url

    assert_response :success
    assert_equal "text/csv", response.media_type
  end

  test "redirects with an alert on invalid dates instead of raising" do
    sign_in_as(users(:elena))

    get sales_report_url, params: { from: "not-a-date" }

    assert_redirected_to root_url
  end

  test "does not include another account's sales" do
    sign_in_as(users(:elena))
    purchase = accounts(:globex).purchases.create!(channel: channels(:globex_fair), title: "Test", currency: "USD")
    purchase.purchase_lines.create!(description: "Card", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 500)
    purchase.confirm_received!
    item = purchase.inventory_items.first
    sale = accounts(:globex).sale_orders.create!(channel: channels(:globex_fair), currency: "USD")
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)
    sale.confirm_payment!
    sale.mark_credited!

    get sales_report_url

    assert_not_includes response.body, item.name
  end
end
