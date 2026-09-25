require "test_helper"

module Cardtrader
  class OrderImporterTest < ActiveSupport::TestCase
    setup do
      @importer = OrderImporter.new(client: Client.new(token: "test-token"))
    end

    test "recent_orders asks the client for the buyer's orders" do
      stub = stub_request(:get, "https://api.cardtrader.com/api/v2/orders")
             .with(query: { "order_as" => "buyer", "limit" => "10", "page" => "1" })
             .to_return(status: 200, body: [ { "id" => 1 } ].to_json)

      result = @importer.recent_orders(limit: 10)

      assert_requested stub
      assert_equal 1, result.length
    end

    test "build_purchase maps a single-item order, including its blueprint" do
      elsa = cardtrader_blueprints(:elsa_blueprint)

      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/555")
        .to_return(status: 200, body: {
          "id" => 555,
          "via_cardtrader_zero" => true,
          "paid_at" => "2026-08-01T10:00:00Z",
          "buyer_subtotal" => { "cents" => 15000, "currency" => "EUR" },
          "order_shipping_method" => { "buyer_price" => { "cents" => 500, "currency" => "EUR" } },
          "order_items" => [
            { "id" => 1, "blueprint_id" => elsa.cardtrader_id, "name" => "Elsa - Snow Queen", "category_id" => 1 }
          ]
        }.to_json)

      purchase = @importer.build_purchase(order_id: 555)

      assert_not purchase.persisted?
      assert_equal 555, purchase.cardtrader_order_id
      assert_equal "CardTrader", purchase.source
      assert_equal true, purchase.via_cardtrader_zero
      assert_equal Date.new(2026, 8, 1), purchase.purchase_date
      assert_equal "Elsa - Snow Queen", purchase.name
      assert_equal 15000, purchase.total_price_cents
      assert_equal 500, purchase.shipping_cost_cents
      assert_equal "EUR", purchase.currency
      assert_equal elsa.cardtrader_id, purchase.cardtrader_blueprint_id
      assert_equal 1, purchase.category_id
      assert_equal elsa.image_url, purchase.blueprint_image_url
    end

    test "build_purchase synthesizes a name and skips blueprint fields for a multi-item order" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/556")
        .to_return(status: 200, body: {
          "id" => 556,
          "via_cardtrader_zero" => false,
          "paid_at" => "2026-08-02T10:00:00Z",
          "buyer_subtotal" => { "cents" => 3000, "currency" => "EUR" },
          "order_shipping_method" => { "buyer_price" => { "cents" => 200, "currency" => "EUR" } },
          "order_items" => [
            { "id" => 1, "blueprint_id" => 501, "name" => "Card A", "category_id" => 1 },
            { "id" => 2, "blueprint_id" => 502, "name" => "Card B", "category_id" => 1 }
          ]
        }.to_json)

      purchase = @importer.build_purchase(order_id: 556)

      assert_equal "Ordine CardTrader #556 (2 articoli)", purchase.name
      assert_nil purchase.cardtrader_blueprint_id
      assert_nil purchase.category_id
      assert_nil purchase.blueprint_image_url
    end

    test "build_purchase falls back to the first item's created_at when paid_at is missing" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/557")
        .to_return(status: 200, body: {
          "id" => 557,
          "buyer_subtotal" => { "cents" => 1000, "currency" => "EUR" },
          "order_items" => [
            { "id" => 1, "blueprint_id" => 501, "name" => "Card A", "created_at" => "2026-07-15T09:00:00Z" }
          ]
        }.to_json)

      purchase = @importer.build_purchase(order_id: 557)

      assert_equal Date.new(2026, 7, 15), purchase.purchase_date
    end

    test "build_purchase leaves purchase_date nil when no date is available" do
      stub_request(:get, "https://api.cardtrader.com/api/v2/orders/558")
        .to_return(status: 200, body: { "id" => 558, "buyer_subtotal" => {}, "order_items" => [] }.to_json)

      purchase = @importer.build_purchase(order_id: 558)

      assert_nil purchase.purchase_date
      assert_equal "Ordine CardTrader #558 (0 articoli)", purchase.name
    end
  end
end
