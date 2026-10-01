require "test_helper"

module Tasks
  class CreditPendingCheckTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
    end

    def sell_and_pay(sold_at:)
      item = @account.inventory_items.create!(
        kind: "single", name: "Card", intent: "sell", status: "in_stock", cost_source: "manual",
        acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
        acquisition_cost_base_cents: 100, cost_base_cents: 100
      )
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR", sold_at: sold_at)
      sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 500)
      sale.confirm_payment!
      sale
    end

    test "opens a credit_pending task when a sale is paid but not credited for over 30 days" do
      sell_and_pay(sold_at: 40.days.ago)

      assert_difference -> { Task.count }, 1 do
        CreditPendingCheck.new(@account).call!
      end

      task = Task.find_by(account: @account, kind: "credit_pending")
      assert_equal 1, task.metadata["count"]
    end

    test "does not open a task for a sale credited or under 30 days old" do
      sell_and_pay(sold_at: 5.days.ago)

      assert_no_difference -> { Task.count } do
        CreditPendingCheck.new(@account).call!
      end
    end

    test "resolves the task once all overdue sales are credited" do
      sale = sell_and_pay(sold_at: 40.days.ago)
      CreditPendingCheck.new(@account).call!
      task = Task.find_by(account: @account, kind: "credit_pending")
      assert_equal "open", task.status

      sale.mark_credited!
      CreditPendingCheck.new(@account).call!

      assert_equal "resolved", task.reload.status
    end

    test "does not create a duplicate task on repeated calls while still overdue" do
      sell_and_pay(sold_at: 40.days.ago)

      CreditPendingCheck.new(@account).call!
      assert_no_difference -> { Task.count } do
        CreditPendingCheck.new(@account).call!
      end
    end
  end
end
