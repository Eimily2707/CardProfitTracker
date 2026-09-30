require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get sales_url
    assert_redirected_to new_session_url
  end

  test "lists the account's sales" do
    sign_in_as(users(:elena))

    get sales_url

    assert_response :success
  end

  test "filters by channel, status, and date range" do
    sign_in_as(users(:elena))
    matching = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR", sold_at: Date.new(2026, 6, 15))
    other_channel = accounts(:acme).sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR", sold_at: Date.new(2026, 6, 15))
    outside_range = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR", sold_at: Date.new(2026, 1, 1))

    get sales_url, params: { channel_id: channels(:acme_fair).id, status: "draft", from: "2026-06-01", to: "2026-06-30" }

    assert_response :success
    assert_select "a[href=?]", sale_path(matching)
    assert_select "a[href=?]", sale_path(other_channel), count: 0
    assert_select "a[href=?]", sale_path(outside_range), count: 0
  end

  test "renders the new sale form" do
    sign_in_as(users(:elena))

    get new_sale_url

    assert_response :success
  end

  test "renders the edit sale form" do
    sign_in_as(users(:elena))
    sale_order = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")

    get edit_sale_url(sale_order)

    assert_response :success
  end

  test "renders the sale show page" do
    sign_in_as(users(:elena))
    item = accounts(:acme).inventory_items.create!(
      kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:acme)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )
    sale_order = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
    sale_order.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)

    get sale_url(sale_order)

    assert_response :success
  end

  test "an operator can create a sale with a line" do
    sign_in_as(users(:operator_user))
    item = accounts(:acme).inventory_items.create!(
      kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:acme)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )

    assert_difference -> { SaleOrder.count }, 1 do
      post sales_url, params: {
        sale_order: {
          channel_id: channels(:acme_fair).id, currency: "EUR",
          sale_lines_attributes: { "0" => { inventory_item_id: item.id, description: item.name, unit_price: "15,00" } }
        }
      }
    end

    sale_order = SaleOrder.order(:created_at).last
    assert_redirected_to sale_url(sale_order)
    assert_equal 1, sale_order.sale_lines.count
    assert_equal 1500, sale_order.sale_lines.first.unit_price_cents
  end

  test "a viewer cannot create a sale" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { SaleOrder.count } do
      post sales_url, params: { sale_order: { channel_id: channels(:acme_fair).id, currency: "EUR" } }
    end
  end

  test "confirming a sale sells the matched inventory item" do
    sign_in_as(users(:elena))
    item = accounts(:acme).inventory_items.create!(
      kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:acme)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )
    sale_order = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
    sale_order.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)

    post confirm_payment_sale_url(sale_order)

    assert_redirected_to sale_url(sale_order)
    assert_equal "paid", sale_order.reload.status
    assert_equal "sold", item.reload.status
  end

  test "confirming an invalid sale shows the error instead of raising" do
    sign_in_as(users(:elena))
    sale_order = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")

    post confirm_payment_sale_url(sale_order)

    assert_redirected_to sale_url(sale_order)
    assert_equal "draft", sale_order.reload.status
  end

  test "only a draft sale can be deleted" do
    sign_in_as(users(:elena))
    item = accounts(:acme).inventory_items.create!(
      kind: "single", name: "Teferi", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:acme)),
      acquisition_cost_base_cents: 500, cost_base_cents: 500
    )
    sale_order = accounts(:acme).sale_orders.create!(channel: channels(:acme_fair), currency: "EUR")
    sale_order.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)
    sale_order.confirm_payment!

    delete sale_url(sale_order)

    assert SaleOrder.exists?(sale_order.id)
  end

  test "sync enqueues a bulk order sync job" do
    sign_in_as(users(:elena))

    assert_enqueued_with(job: Cardtrader::SyncOrdersJob) do
      post sync_sales_url
    end

    assert_redirected_to sales_url
  end

  test "sync_one enqueues a single-order sync job" do
    sign_in_as(users(:elena))

    assert_enqueued_with(job: Cardtrader::SyncSingleOrderJob) do
      post sync_one_sales_url, params: { external_order_id: "12345" }
    end

    assert_redirected_to sales_url
  end

  test "sync_one requires an order id" do
    sign_in_as(users(:elena))

    assert_no_enqueued_jobs only: Cardtrader::SyncSingleOrderJob do
      post sync_one_sales_url, params: { external_order_id: "" }
    end
  end

  test "a viewer cannot trigger a sync" do
    sign_in_as(users(:viewer_user))

    assert_no_enqueued_jobs only: Cardtrader::SyncOrdersJob do
      post sync_sales_url
    end
  end
end
