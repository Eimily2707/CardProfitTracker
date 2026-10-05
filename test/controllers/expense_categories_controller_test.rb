require "test_helper"

class ExpenseCategoriesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get expense_categories_url
    assert_redirected_to new_session_url
  end

  test "lists the account's expense categories" do
    sign_in_as(users(:elena))

    get expense_categories_url

    assert_response :success
    assert_select "td", text: /Fiera/
  end

  test "a viewer cannot create a category" do
    sign_in_as(users(:viewer_user))

    assert_no_difference -> { ExpenseCategory.count } do
      post expense_categories_url, params: { expense_category: { name: "Nuova" } }
    end

    assert_response :redirect
  end

  test "an operator can create a custom category" do
    sign_in_as(users(:operator_user))

    assert_difference -> { ExpenseCategory.count }, 1 do
      post expense_categories_url, params: { expense_category: { name: "Nuova" } }
    end

    assert_redirected_to expense_categories_url
  end

  test "cannot destroy a system category" do
    sign_in_as(users(:elena))

    assert_no_difference -> { ExpenseCategory.count } do
      delete expense_category_url(expense_categories(:acme_fair))
    end

    assert_redirected_to expense_categories_url
  end

  test "can destroy a custom category" do
    sign_in_as(users(:elena))

    assert_difference -> { ExpenseCategory.count }, -1 do
      delete expense_category_url(expense_categories(:acme_custom))
    end
  end
end
