module Expenses
  # spec §4.12/§6.10 US-10.1: "le spese ricorrenti propongono ogni periodo
  # una bozza da confermare, e compaiono in 'Da sistemare'". Runs daily
  # (config/recurring.yml); idempotent per series - a confirmed expense
  # with recurrence only ever gets one successor (where.missing(:successor)
  # excludes it the moment that successor, draft or not, exists), so a
  # re-run never double-generates one.
  class GenerateRecurringDraftsService
    def self.call!
      Account.find_each { |account| new(account).call! }
    end

    def initialize(account)
      @account = account
    end

    def call!
      due_expenses.find_each { |expense| generate_successor!(expense) }
    end

    private

    attr_reader :account

    def due_expenses
      account.expenses.recurring.confirmed.where.missing(:successor)
    end

    def generate_successor!(expense)
      next_date = next_occurrence(expense)
      return if next_date > Date.current

      ApplicationRecord.transaction do
        draft = account.expenses.create!(
          expense_category: expense.expense_category, channel: expense.channel,
          description: expense.description, supplier_ref: expense.supplier_ref,
          incurred_on: next_date, currency: expense.currency, amount_cents: expense.amount_cents,
          recurrence: expense.recurrence, status: "draft", source_expense: expense
        )
        Task.open_or_create!(kind: "recurring_expense", subject: draft, account: account, priority: "normal")
      end
    end

    def next_occurrence(expense)
      expense.recurrence == "monthly" ? expense.incurred_on + 1.month : expense.incurred_on + 1.year
    end
  end
end
