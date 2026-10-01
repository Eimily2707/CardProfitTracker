require "test_helper"

module Profits
  class CalculatorServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @service = CalculatorService.new(@account)
    end

    def buy_two_teferis(unit_price_cents: 500)
      purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
      purchase.purchase_lines.create!(
        ct_blueprint: ct_blueprints(:teferi), description: "Teferi, Time Raveler", kind: "single", intent: "sell",
        quantity: 2, unit_price_cents: unit_price_cents
      )
      purchase.confirm_received!
      purchase.inventory_items.order(:id)
    end

    def sell(items, unit_price_cents: 1000, shipping_cents: 200, fee_cents: 100)
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      items.each { |item| sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: unit_price_cents) }
      sale.sale_charges.create!(kind: "shipping_charged", amount_cents: shipping_cents)
      sale.sale_charges.create!(kind: "platform_fee", amount_cents: fee_cents)
      sale.confirm_payment!
      sale
    end

    test "invested_capital_base_cents sums the cost of items not yet sold" do
      buy_two_teferis(unit_price_cents: 500)

      assert_equal 1000, @service.invested_capital_base_cents
    end

    test "invested_capital_base_cents excludes sold items" do
      items = buy_two_teferis(unit_price_cents: 500)
      sell(items)

      assert_equal 0, @service.invested_capital_base_cents
    end

    test "invested_capital_base_cents includes the residual of still-open cost pools" do
      sealed = @account.inventory_items.create!(
        kind: "sealed", name: "Booster Box", intent: "crack", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 10_000, cost_base_cents: 10_000
      )
      pool = CostPools::OpenService.new(sealed).call!
      pool.update!(allocation_method: "manual")

      assert_equal 10_000, @service.invested_capital_base_cents

      # splitting the pool's cost between an allocated item (4000) and its
      # still-open residual (6000) must not change the account-wide total.
      CostPools::ExtractItemsService.new(pool).call!(name: "Card", kind: "single", quantity: 1, manual_cost_cents: 4_000)

      assert_equal 10_000, @service.invested_capital_base_cents
      assert_kind_of Integer, @service.invested_capital_base_cents
    end

    test "realized_profit_base_cents only counts credited orders" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items, unit_price_cents: 1000, shipping_cents: 200, fee_cents: 100)

      assert_equal 0, @service.realized_profit_base_cents # not credited yet

      sale.mark_credited!

      # items_subtotal 2000 + income 200 - expense 100 = net 2100; cogs 1000 -> profit 1100
      assert_equal 1100, @service.realized_profit_base_cents
      assert_equal 1000, @service.cogs_base_cents
    end

    test "roi_percent is the aggregate ratio, not an average of per-order ROIs, and nil with zero cogs" do
      assert_nil @service.roi_percent

      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items)
      sale.mark_credited!

      assert_equal 110.0, @service.roi_percent
    end

    test "uncredited_summary counts paid-but-not-credited orders" do
      items = buy_two_teferis
      sale = sell(items)

      summary = @service.uncredited_summary
      assert_equal 1, summary[:count]
      assert_equal sale.net_proceeds_base_cents, summary[:net_proceeds_base_cents]

      sale.mark_credited!
      assert_equal 0, @service.uncredited_summary[:count]
    end

    test "profit_by_channel groups credited profit by the sale channel" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items)
      sale.mark_credited!

      assert_equal({ "CardTrader" => 1100 }, @service.profit_by_channel)
    end

    test "profit_by_game and profit_by_expansion split the order's net charges per line, cent-perfect" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items, unit_price_cents: 1000, shipping_cents: 200, fee_cents: 100)
      sale.mark_credited!

      by_game = @service.profit_by_game
      by_expansion = @service.profit_by_expansion

      assert_equal 1100, by_game.values.sum
      assert_equal 1100, by_expansion.values.sum
      assert_includes by_game.keys, ct_blueprints(:teferi).ct_game.display_name
    end

    test "top_cards ranks by profit and sums quantity" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items, unit_price_cents: 1000)
      sale.mark_credited!

      top = @service.top_cards
      assert_equal 1, top.size
      assert_equal 2, top.first[:quantity]
      assert_equal 1100, top.first[:profit_base_cents]
    end

    test "inventory_aging buckets in_stock items by days since acquired_on" do
      old_item = @account.inventory_items.create!(
        kind: "single", name: "Old card", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: 100.days.ago.to_date, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 100, cost_base_cents: 100
      )
      new_item = @account.inventory_items.create!(
        kind: "single", name: "New card", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: 5.days.ago.to_date, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 200, cost_base_cents: 200
      )

      buckets = @service.inventory_aging

      assert_equal 1, buckets[91..180][:count]
      assert_equal old_item.cost_base_cents, buckets[91..180][:cost_base_cents]
      assert_equal 1, buckets[0..30][:count]
      assert_equal new_item.cost_base_cents, buckets[0..30][:cost_base_cents]
    end

    test "purchase_channel_x_sale_channel_matrix groups by the buy and sell channel pair" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items, unit_price_cents: 1000)
      sale.mark_credited!

      matrix = @service.purchase_channel_x_sale_channel_matrix
      assert_equal 1, matrix.size
      row = matrix.first
      assert_equal "Fiera", row[:purchase_channel]
      assert_equal "CardTrader", row[:sale_channel]
      assert_equal 2, row[:quantity]
      assert_equal 1100, row[:profit_base_cents]
    end

    test "does not leak another account's data" do
      items = buy_two_teferis(unit_price_cents: 500)
      sale = sell(items)
      sale.mark_credited!

      other_service = CalculatorService.new(accounts(:globex))
      assert_equal 0, other_service.realized_profit_base_cents
      assert_equal 0, other_service.invested_capital_base_cents
    end
  end
end
