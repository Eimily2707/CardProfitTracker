require "test_helper"

module Expenses
  class GenerateRecurringDraftsJobTest < ActiveJob::TestCase
    test "delegates to GenerateRecurringDraftsService" do
      account = accounts(:acme)
      expense = account.expenses.create!(
        expense_category: expense_categories(:acme_fair), incurred_on: 2.months.ago.to_date,
        currency: "EUR", amount_cents: 1_000, recurrence: "monthly"
      )
      expense.confirm!

      assert_difference -> { account.expenses.count }, 1 do
        GenerateRecurringDraftsJob.perform_now
      end
    end
  end
end
