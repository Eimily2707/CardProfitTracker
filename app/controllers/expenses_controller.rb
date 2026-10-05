# spec §6.10 M10 US-10.1.
class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[show edit update destroy confirm]

  def index
    authorize Expense
    @expenses = policy_scope(Expense).includes(:expense_category, :channel).order(incurred_on: :desc)
    @expenses = @expenses.where(expense_category_id: params[:expense_category_id]) if params[:expense_category_id].present?
    @expenses = @expenses.where(channel_id: params[:channel_id]) if params[:channel_id].present?
    @expenses = @expenses.where(status: params[:status]) if params[:status].present?
    @expenses = @expenses.where(incurred_on: params[:from].to_date..) if params[:from].present?
    @expenses = @expenses.where(incurred_on: ..params[:to].to_date) if params[:to].present?
  end

  def show
  end

  def new
    @expense = Current.account.expenses.new(currency: Current.account.base_currency, incurred_on: Date.current)
    authorize @expense
  end

  def create
    @expense = Current.account.expenses.new(expense_params)
    @expense.created_by = Current.user
    authorize @expense

    if @expense.save
      redirect_to @expense, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to @expense, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @expense.destroy
      redirect_to expenses_path, notice: t(".success"), status: :see_other
    else
      redirect_to @expense, alert: @expense.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def confirm
    authorize @expense, :transition?
    @expense.confirm!
    redirect_to @expense, notice: t(".confirmed")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @expense, alert: transition_error_message(e)
  end

  private

  def set_expense
    @expense = Current.account.expenses.find(params[:id])
    authorize @expense unless action_name == "confirm"
  end

  def transition_error_message(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def expense_params
    params.require(:expense).permit(
      :expense_category_id, :channel_id, :description, :supplier_ref, :incurred_on,
      :currency, :amount, :fx_rate, :recurrence, :receipt
    )
  end
end
