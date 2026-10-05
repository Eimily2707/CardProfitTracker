require "test_helper"

module Expenses
  class GenerateRecurringDraftsServiceTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:acme)
      @category = expense_categories(:acme_fair)
    end

    def confirmed_recurring(incurred_on:, recurrence: "monthly")
      expense = @account.expenses.create!(
        expense_category: @category, incurred_on: incurred_on, currency: "EUR", amount_cents: 1_000, recurrence: recurrence
      )
      expense.confirm!
      expense
    end

    test "generates a draft successor once the next period is due" do
      expense = confirmed_recurring(incurred_on: 2.months.ago.to_date)

      assert_difference -> { @account.expenses.count }, 1 do
        GenerateRecurringDraftsService.call!
      end

      successor = expense.reload.successor
      assert_equal "draft", successor.status
      assert_equal expense.incurred_on + 1.month, successor.incurred_on
      assert_equal expense.amount_cents, successor.amount_cents
      assert_equal expense, successor.source_expense
    end

    test "opens a recurring_expense task for the new draft" do
      expense = confirmed_recurring(incurred_on: 2.months.ago.to_date)

      GenerateRecurringDraftsService.call!

      task = Task.find_by(subject: expense.reload.successor)
      assert_equal "recurring_expense", task.kind
      assert_equal "open", task.status
    end

    test "does not generate a successor before the next period is due" do
      confirmed_recurring(incurred_on: Date.current)

      assert_no_difference -> { @account.expenses.count } do
        GenerateRecurringDraftsService.call!
      end
    end

    test "does not generate a second successor once one already exists" do
      expense = confirmed_recurring(incurred_on: 2.months.ago.to_date)
      GenerateRecurringDraftsService.call!

      assert_no_difference -> { @account.expenses.count } do
        GenerateRecurringDraftsService.call!
      end
    end

    test "ignores non-recurring and draft expenses" do
      @account.expenses.create!(
        expense_category: @category, incurred_on: 2.months.ago.to_date, currency: "EUR", amount_cents: 1_000, recurrence: "none"
      ).confirm!
      @account.expenses.create!(
        expense_category: @category, incurred_on: 2.months.ago.to_date, currency: "EUR", amount_cents: 1_000, recurrence: "monthly"
      ) # left as draft

      assert_no_difference -> { @account.expenses.count } do
        GenerateRecurringDraftsService.call!
      end
    end

    test "yearly recurrence advances by a year" do
      expense = confirmed_recurring(incurred_on: 13.months.ago.to_date, recurrence: "yearly")

      GenerateRecurringDraftsService.call!

      assert_equal expense.incurred_on + 1.year, expense.reload.successor.incurred_on
    end
  end
end
