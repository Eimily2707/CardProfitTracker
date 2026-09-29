require "test_helper"

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get purchases_url
    assert_redirected_to new_session_url
  end

  test "lists the account's purchases" do
    sign_in_as(users(:elena))

    get purchases_url

    assert_response :success
    assert_select "td", text: /Bulk da fiera/
  end

  test "does not list another account's purchases" do
    sign_in_as(users(:elena))

    get purchases_url

    assert_response :success
    assert_select "td", text: /Con Local Shop/, count: 0
  end

  test "an operator can create a purchase with lines and charges" do
    sign_in_as(users(:operator_user))
    blueprint = ct_blueprints(:teferi)

    assert_difference -> { Purchase.count }, 1 do
      post purchases_url, params: {
        purchase: {
          channel_id: channels(:acme_fair).id, title: "Fiera di Modena", currency: "EUR", ordered_at: Date.current,
          purchase_lines_attributes: {
            "0" => { ct_blueprint_id: blueprint.id, description: blueprint.name, kind: "single", intent: "sell", quantity: 2, unit_price: "1,50" }
          },
          purchase_charges_attributes: {
            "0" => { kind: "shipping", amount: "5,00" }
          }
        }
      }
    end

    purchase = Purchase.order(:created_at).last
    assert_redirected_to purchase_url(purchase)
    assert_equal 1, purchase.purchase_lines.count
    assert_equal 150, purchase.purchase_lines.first.unit_price_cents
    assert_equal 1, purchase.purchase_charges.count
    assert_equal 500, purchase.purchase_charges.first.amount_cents
  end

  test "a viewer cannot create a purchase" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { Purchase.count } do
      post purchases_url, params: { purchase: { channel_id: channels(:acme_fair).id, title: "X", currency: "EUR" } }
    end
  end

  test "confirming a purchase generates inventory items" do
    sign_in_as(users(:elena))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "T", currency: "EUR")
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 2, unit_price_cents: 100)

    post confirm_purchase_url(purchase)

    assert_redirected_to purchase_url(purchase)
    assert_equal "ordered", purchase.reload.status
    assert_equal 2, purchase.inventory_items.count
  end

  test "confirming an invalid purchase shows the error instead of raising" do
    sign_in_as(users(:elena))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "T", currency: "EUR")

    post confirm_purchase_url(purchase)

    assert_redirected_to purchase_url(purchase)
    assert_equal "draft", purchase.reload.status
  end

  test "a viewer cannot confirm a purchase" do
    sign_in_as(users(:viewer_user))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "T", currency: "EUR")
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)

    post confirm_purchase_url(purchase)

    assert_equal "draft", purchase.reload.status
  end

  test "only a draft purchase can be deleted" do
    sign_in_as(users(:elena))
    purchase = accounts(:acme).purchases.create!(channel: channels(:acme_fair), title: "T", currency: "EUR")
    purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)
    purchase.confirm!

    delete purchase_url(purchase)

    assert Purchase.exists?(purchase.id)
  end
end
