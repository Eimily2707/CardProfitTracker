require "test_helper"

module Reports
  class ExportCsvServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @service = ExportCsvService.new(@account)
    end

    test "sales_csv includes one row per active line on credited orders, with its profit breakdown" do
      purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
      purchase.purchase_lines.create!(
        ct_blueprint: ct_blueprints(:teferi), description: "Teferi, Time Raveler", kind: "single", intent: "sell",
        quantity: 1, unit_price_cents: 500
      )
      purchase.confirm_received!
      item = purchase.inventory_items.first

      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)
      sale.confirm_payment!
      sale.mark_credited!

      rows = CSV.parse(@service.sales_csv, headers: true)

      assert_equal 1, rows.size
      assert_equal "Teferi, Time Raveler", rows.first["line_description"]
      assert_equal "1", rows.first["quantity"]
    end

    test "sales_csv excludes uncredited orders" do
      purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
      purchase.purchase_lines.create!(description: "Card", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 500)
      purchase.confirm_received!
      item = purchase.inventory_items.first

      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 1500)
      sale.confirm_payment!

      rows = CSV.parse(@service.sales_csv, headers: true)
      assert_equal 0, rows.size
    end

    test "inventory_valuation_csv lists items not yet sold, with days in stock" do
      item = @account.inventory_items.create!(
        kind: "single", name: "Old card", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: 10.days.ago.to_date, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 100, cost_base_cents: 100
      )

      rows = CSV.parse(@service.inventory_valuation_csv, headers: true)

      assert_equal 1, rows.size
      assert_equal item.public_ref, rows.first["public_ref"]
      assert_equal "10", rows.first["days_in_stock"]
    end

    test "does not leak another account's data" do
      accounts(:globex).inventory_items.create!(
        kind: "single", name: "Other account card", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(accounts(:globex)),
        acquisition_cost_base_cents: 100, cost_base_cents: 100
      )

      rows = CSV.parse(@service.inventory_valuation_csv, headers: true)
      assert_equal 0, rows.size
    end
  end
end
