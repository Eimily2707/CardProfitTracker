# Named SalesController (not SaleOrdersController) to match the M5 "Sales"
# workflow users see, even though the underlying model is SaleOrder (spec
# §4.7 names it that way, to leave "Sale" free for a future line-item-level
# concept - see PurchasesController for the equivalent on the buy side).
class SalesController < ApplicationController
  before_action :set_sale, only: %i[show edit update destroy submit confirm_payment ship deliver cancel]

  # spec §6.5 US-5.1 "Elenco... con filtri per canale, stato e data".
  def index
    authorize SaleOrder
    @sale_orders = policy_scope(SaleOrder).includes(:channel).order(created_at: :desc)
    @sale_orders = @sale_orders.where(channel_id: params[:channel_id]) if params[:channel_id].present?
    @sale_orders = @sale_orders.where(status: params[:status]) if params[:status].present?
    @sale_orders = @sale_orders.where(sold_at: params[:from].to_date..) if params[:from].present?
    @sale_orders = @sale_orders.where(sold_at: ..params[:to].to_date.end_of_day) if params[:to].present?
  end

  def show
  end

  def new
    @sale_order = Current.account.sale_orders.new(currency: Current.account.base_currency)
    authorize @sale_order
    @sale_order.sale_lines.build
  end

  def create
    @sale_order = Current.account.sale_orders.new(sale_order_params)
    @sale_order.created_by = Current.user
    authorize @sale_order

    if @sale_order.save
      redirect_to sale_path(@sale_order), notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @sale_order.sale_lines.build if @sale_order.sale_lines.empty?
  end

  def update
    if @sale_order.update(sale_order_params)
      redirect_to sale_path(@sale_order), notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @sale_order.destroy
      redirect_to sales_path, notice: t(".success"), status: :see_other
    else
      redirect_to sale_path(@sale_order), alert: @sale_order.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def submit
    authorize @sale_order, :transition?
    @sale_order.submit!
    redirect_to sale_path(@sale_order), notice: t(".submitted")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to sale_path(@sale_order), alert: transition_error_message(e)
  end

  def confirm_payment
    authorize @sale_order, :transition?
    @sale_order.confirm_payment!
    redirect_to sale_path(@sale_order), notice: t(".paid")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to sale_path(@sale_order), alert: transition_error_message(e)
  end

  def ship
    authorize @sale_order, :transition?
    @sale_order.ship!
    redirect_to sale_path(@sale_order), notice: t(".shipped")
  rescue ArgumentError => e
    redirect_to sale_path(@sale_order), alert: e.message
  end

  def deliver
    authorize @sale_order, :transition?
    @sale_order.deliver!
    redirect_to sale_path(@sale_order), notice: t(".delivered")
  rescue ArgumentError => e
    redirect_to sale_path(@sale_order), alert: e.message
  end

  def cancel
    authorize @sale_order, :transition?
    @sale_order.cancel!
    redirect_to sale_path(@sale_order), notice: t(".cancelled")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to sale_path(@sale_order), alert: transition_error_message(e)
  end

  # US-2.3-style bulk import (spec §9.1 ct_user_bulk): syncs every seller
  # order in the background; the sync run's progress shows via Turbo Streams
  # (Cardtrader::OrderSyncRun#broadcasts_refreshes).
  def sync
    authorize Cardtrader::OrderSyncRun, :create?
    Cardtrader::SyncOrdersJob.perform_later(Current.account.id, trigger: "manual", triggered_by_id: Current.user.id)
    redirect_to sales_path, notice: t(".sync_started")
  end

  # US-2.2-style single-order import (spec §9.1 ct_user_interactive).
  def sync_one
    authorize Cardtrader::OrderSyncRun, :create?

    if params[:external_order_id].blank?
      redirect_to sales_path, alert: t(".missing_order_id")
      return
    end

    Cardtrader::SyncSingleOrderJob.perform_later(Current.account.id, params[:external_order_id], triggered_by_id: Current.user.id)
    redirect_to sales_path, notice: t(".sync_started")
  end

  private

  def set_sale
    @sale_order = Current.account.sale_orders.find(params[:id])
    # submit/confirm_payment/ship/deliver/cancel authorize explicitly against
    # :transition? in their own action - Pundit's implicit action-name
    # lookup would otherwise look for submit?/ship?/... methods that don't exist.
    authorize @sale_order unless %w[submit confirm_payment ship deliver cancel].include?(action_name)
  end

  def transition_error_message(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def sale_order_params
    params.require(:sale_order).permit(
      :channel_id, :buyer_ref, :sold_at, :currency, :fx_rate, :payment_method, :notes,
      sale_lines_attributes: %i[id inventory_item_id description unit_price _destroy],
      sale_charges_attributes: %i[id kind amount _destroy]
    )
  end
end
