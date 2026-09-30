require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "renders the dashboard for a signed-in user with an account" do
    sign_in_as(users(:elena))

    get root_url

    assert_response :success
  end

  test "renders each period" do
    sign_in_as(users(:elena))

    %w[month quarter year custom].each do |period|
      get root_url, params: { period: period }
      assert_response :success
    end
  end

  test "renders with real purchase/sale data flowing through the KPIs" do
    sign_in_as(users(:elena))
    account = accounts(:acme)
    purchase = account.purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
    purchase.purchase_lines.create!(
      ct_blueprint: ct_blueprints(:teferi), description: "Teferi, Time Raveler", kind: "single", intent: "sell",
      quantity: 1, unit_price_cents: 500
    )
    purchase.confirm_received!
    item = purchase.inventory_items.first

    sale = account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
    sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)
    sale.confirm_payment!
    sale.mark_credited!

    get root_url

    assert_response :success
  end

  test "requires authentication" do
    get root_url
    assert_redirected_to new_session_url
  end
end
