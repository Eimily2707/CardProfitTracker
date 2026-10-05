require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
    @category = expense_categories(:acme_fair)
  end

  def build_expense(**overrides)
    @account.expenses.create!({
      expense_category: @category, incurred_on: Date.current, currency: "EUR", amount_cents: 5_000
    }.merge(overrides))
  end

  test "valid with the required attributes" do
    expense = build_expense
    assert expense.valid?
    assert_equal "draft", expense.status
  end

  test "requires a non-zero amount" do
    expense = Expense.new(account: @account, expense_category: @category, incurred_on: Date.current, currency: "EUR", amount_cents: 0)

    assert_not expense.valid?
  end

  test "allows a negative amount (refund or credit note)" do
    expense = build_expense(amount_cents: -500)

    assert expense.valid?
  end

  test "confirm! fixes the fx_rate and computes amount_base_cents" do
    expense = build_expense

    expense.confirm!

    assert_equal "confirmed", expense.status
    assert_equal 1, expense.fx_rate
    assert_equal 5_000, expense.amount_base_cents
    assert_equal expense.incurred_on, expense.fx_rate_date
  end

  test "confirm! converts a foreign currency using the given fx_rate" do
    expense = build_expense(currency: "USD", amount_cents: 1_000, fx_rate: 0.9)

    expense.confirm!

    assert_equal 900, expense.amount_base_cents
  end

  test "confirm! requires an fx_rate for a foreign currency" do
    expense = build_expense(currency: "USD", amount_cents: 1_000)

    assert_raises(ActiveRecord::RecordInvalid) { expense.confirm! }
  end

  test "cannot confirm an already-confirmed expense" do
    expense = build_expense
    expense.confirm!

    assert_raises(ArgumentError) { expense.confirm! }
  end

  test "only draft expenses can be destroyed" do
    expense = build_expense
    expense.confirm!

    assert_not expense.destroy
    assert expense.errors.of_kind?(:base, :only_drafts_can_be_deleted)
  end

  test "a draft expense can be destroyed" do
    expense = build_expense

    assert expense.destroy
  end
end
