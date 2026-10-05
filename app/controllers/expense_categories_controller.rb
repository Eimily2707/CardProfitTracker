class ExpenseCategoriesController < ApplicationController
  before_action :set_expense_category, only: %i[edit update destroy]

  def index
    authorize ExpenseCategory
    @expense_categories = policy_scope(ExpenseCategory).order(:name)
  end

  def new
    @expense_category = Current.account.expense_categories.new
    authorize @expense_category
  end

  def create
    @expense_category = Current.account.expense_categories.new(expense_category_params)
    authorize @expense_category

    if @expense_category.save
      redirect_to expense_categories_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense_category.update(expense_category_params)
      redirect_to expense_categories_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @expense_category.destroy
      redirect_to expense_categories_path, notice: t(".success"), status: :see_other
    else
      redirect_to expense_categories_path, alert: @expense_category.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def set_expense_category
    @expense_category = Current.account.expense_categories.find(params[:id])
    authorize @expense_category
  end

  def expense_category_params
    params.require(:expense_category).permit(:name, :active)
  end
end
