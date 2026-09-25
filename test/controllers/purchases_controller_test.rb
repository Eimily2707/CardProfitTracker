require "test_helper"

class PurchasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @purchase = purchases(:lorcana_box)
    # PurchasesController builds its own Cardtrader::Client with no token override,
    # so the import_from_cardtrader tests need one configured before WebMock ever
    # gets a chance to answer the stubbed request.
    ENV["CARDTRADER_API_TOKEN"] = "test-token"
  end

  teardown do
    ENV.delete("CARDTRADER_API_TOKEN")
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

  test "destroying a purchase whose sealed item was already sold is blocked with an alert" do
    purchase = Purchase.create!(
      name: "Sealed box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10_000, shipping_cost_cents: 0
    )
    Sale.create!(inventory_item: purchase.sealed_inventory_item, sale_date: Date.current, sale_price_cents: 20_000)

    assert_no_difference("Purchase.count") do
      delete purchase_url(purchase)
    end

    assert_redirected_to purchase_url(purchase)
    follow_redirect!
    assert_match "già venduto", response.body
  end

  test "creating a keep_sealed purchase auto-creates its sealed inventory item" do
    assert_difference("InventoryItem.count", 1) do
      post purchases_url, params: {
        purchase: {
          name: "Booster Box Lorcana", currency: "EUR", intent_type: "keep_sealed",
          total_price: "150.00", shipping_cost: "5.00"
        }
      }
    end

    purchase = Purchase.order(:created_at).last
    assert purchase.keep_sealed?
    assert_equal 15500, purchase.sealed_inventory_item.allocated_cost_cents
  end

  test "show renders the sealed product badge instead of the unboxing form for a keep_sealed purchase" do
    purchase = Purchase.create!(
      name: "Sealed box", currency: "EUR", intent_type: "keep_sealed",
      total_price_cents: 10_000, shipping_cost_cents: 0
    )

    get purchase_url(purchase)

    assert_response :success
    assert_match "Prodotto Sigillato in Inventario", response.body
    assert_no_match "Spacchettamento", response.body
  end

  test "import_from_cardtrader lists recent orders" do
    stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
      .with(query: hash_including({ "order_as" => "buyer" }))
      .to_return(status: 200, body: [
        { "id" => 900, "state" => "paid", "size" => 1, "buyer_total" => { "cents" => 1500, "currency" => "EUR" } }
      ].to_json)

    get import_from_cardtrader_purchases_url

    assert_response :success
    assert_match "#900", response.body
  end

  test "import_from_cardtrader prefills the new purchase form from an order" do
    stub_request(:get, "https://api.cardtrader.com/api/v2/orders/901")
      .to_return(status: 200, body: {
        "id" => 901, "via_cardtrader_zero" => true, "paid_at" => "2026-08-01T10:00:00Z",
        "buyer_subtotal" => { "cents" => 5000, "currency" => "EUR" },
        "order_shipping_method" => { "buyer_price" => { "cents" => 300, "currency" => "EUR" } },
        "order_items" => [ { "id" => 1, "blueprint_id" => 501, "name" => "Imported Card", "category_id" => 1 } ]
      }.to_json)

    get import_from_cardtrader_purchases_url(order_id: 901)

    assert_response :success
    assert_match "Imported Card", response.body
  end

  test "import_from_cardtrader redirects with an alert when the API call fails" do
    stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
      .with(query: hash_including({ "order_as" => "buyer" }))
      .to_return(status: 401, body: '{"error":"unauthorized"}')

    get import_from_cardtrader_purchases_url

    assert_redirected_to new_purchase_url
    follow_redirect!
    assert_match "Impossibile importare da CardTrader", response.body
  end
end
