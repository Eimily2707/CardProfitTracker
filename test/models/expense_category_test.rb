require "test_helper"

class ExpenseCategoryTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
  end

  test "seed_defaults_for! creates the preloaded categories" do
    account = Account.create!(name: "Fresh", country: "IT", time_zone: "UTC", base_currency: "EUR")

    assert_equal ExpenseCategory::SYSTEM_CATEGORIES.map { |c| c[:system_key] }.sort,
                 account.expense_categories.pluck(:system_key).sort
  end

  test "seed_defaults_for! is idempotent" do
    ExpenseCategory.seed_defaults_for!(@account)

    assert_no_difference -> { @account.expense_categories.count } do
      ExpenseCategory.seed_defaults_for!(@account)
    end
  end

  test "system categories cannot be destroyed" do
    category = @account.expense_categories.find_by(system_key: "fair")

    assert_not category.destroy
    assert category.errors.of_kind?(:base, :system_category_not_deletable)
  end

  test "custom categories can be destroyed" do
    category = @account.expense_categories.create!(name: "Custom")

    assert category.destroy
  end

  test "requires a unique name per account" do
    duplicate = @account.expense_categories.new(name: @account.expense_categories.first.name)

    assert_not duplicate.valid?
  end
end
