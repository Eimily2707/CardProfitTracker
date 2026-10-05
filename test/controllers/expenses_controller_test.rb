require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:acme)
    @category = expense_categories(:acme_fair)
  end

  test "requires authentication" do
    get expenses_url
    assert_redirected_to new_session_url
  end

  test "lists the account's expenses" do
    sign_in_as(users(:elena))
    expense = @account.expenses.create!(expense_category: @category, incurred_on: Date.current, currency: "EUR", amount_cents: 2_000)

    get expenses_url

    assert_response :success
    assert_select "td", text: /Fiera/
  end

  test "a viewer cannot create an expense" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { Expense.count } do
      # operator_user/viewer_user's locale is Italian - money fields expect comma-decimal input.
      post expenses_url, params: { expense: { expense_category_id: @category.id, incurred_on: Date.current, currency: "EUR", amount: "20,00" } }
    end

    assert_response :redirect
  end

  test "an operator can create and confirm an expense" do
    sign_in_as(users(:operator_user))

    assert_difference -> { Expense.count }, 1 do
      post expenses_url, params: { expense: { expense_category_id: @category.id, incurred_on: Date.current, currency: "EUR", amount: "20,00" } }
    end

    expense = Expense.last
    assert_equal 2_000, expense.amount_cents
    assert_equal "draft", expense.status

    post confirm_expense_url(expense)
    assert_equal "confirmed", expense.reload.status
  end

  test "a confirmed expense cannot be edited or destroyed" do
    sign_in_as(users(:elena))
    expense = @account.expenses.create!(expense_category: @category, incurred_on: Date.current, currency: "EUR", amount_cents: 2_000)
    expense.confirm!

    patch expense_url(expense), params: { expense: { description: "changed" } }
    assert_not_equal "changed", expense.reload.description

    delete expense_url(expense)
    assert expense.reload.persisted?
  end

  test "does not expose another account's expenses" do
    sign_in_as(users(:elena))
    other_category = expense_categories(:globex_fair)
    other_expense = accounts(:globex).expenses.create!(
      expense_category: other_category, incurred_on: Date.current, currency: "USD", amount_cents: 1_000
    )

    get expense_url(other_expense)

    assert_response :not_found
  end
end
