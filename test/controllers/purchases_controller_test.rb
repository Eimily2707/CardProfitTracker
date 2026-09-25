require "test_helper"

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @purchase = purchases(:lorcana_box)
  end

  test "should get index" do
    get purchases_url
    assert_response :success
  end

  test "index lists purchase names" do
    get purchases_url
    assert_match @purchase.name, response.body
  end

  test "should get new" do
    get new_purchase_url
    assert_response :success
  end

  test "should create a purchase converting euro amounts to cents" do
    assert_difference("Purchase.count", 1) do
      post purchases_url, params: {
        purchase: {
          name: "Nuovo box di prova",
          source: "CardTrader",
          product_type: "sealed_box",
          purchase_date: Date.current,
          total_price: "120.50",
          shipping_cost: "9.99",
          tax: "5",
          currency: "EUR",
          via_cardtrader_zero: "0"
        }
      }
    end

    purchase = Purchase.order(:created_at).last
    assert_redirected_to purchase_url(purchase)
    assert_equal 12050, purchase.total_price_cents
    assert_equal 999, purchase.shipping_cost_cents
    assert_equal 500, purchase.tax_cents
  end

  test "should not create an invalid purchase" do
    assert_no_difference("Purchase.count") do
      post purchases_url, params: { purchase: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should show the purchase with its KPI totals" do
    get purchase_url(@purchase)

    assert_response :success
    assert_match @purchase.name, response.body
    assert_match "€155,00", response.body # costo totale speso (150 + 5 + 0)
    assert_match "€46,50", response.body  # costo attribuito totale (45 + 1.50)
    assert_match "€108,50", response.body # costo rimanente da allocare ((150 + 5) - 46,50)
  end

  test "should get edit" do
    get edit_purchase_url(@purchase)
    assert_response :success
  end

  test "should update the purchase" do
    patch purchase_url(@purchase), params: { purchase: { name: "Nome aggiornato" } }
    assert_redirected_to purchase_url(@purchase)
    assert_equal "Nome aggiornato", @purchase.reload.name
  end

  test "should destroy the purchase" do
    assert_difference("Purchase.count", -1) do
      delete purchase_url(@purchase)
    end

    assert_redirected_to purchases_url
  end
end
