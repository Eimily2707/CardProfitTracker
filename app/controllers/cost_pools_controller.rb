# spec §6.3 M3 - the unboxing/allocation screen (US-3.1/3.2/3.3). Every
# action name here matches a CostPoolPolicy method 1:1 (show?/update?/
# close?/reopen?), so Pundit's implicit action-name lookup just works.
class CostPoolsController < ApplicationController
  before_action :set_pool

  def show
    @extracted_items = @pool.extracted_items.order(created_at: :asc)
  end

  def update
    CostPools::ChangeMethodService.new(@pool).call!(params[:allocation_method])
    redirect_to @pool, notice: t(".success")
  rescue ArgumentError, ActiveRecord::RecordInvalid, CostPools::AllocationService::PoolExceededError => e
    redirect_to @pool, alert: transition_error_message(e)
  end

  def close
    CostPools::CloseService.new(@pool).call!(
      action: params[:close_action], reason: params[:reason].presence, occurred_on: params[:occurred_on].presence || Date.current
    )
    redirect_to @pool, notice: t(".closed")
  rescue ArgumentError, ActiveRecord::RecordInvalid, CostPools::AllocationService::PoolExceededError => e
    redirect_to @pool, alert: transition_error_message(e)
  end

  def reopen
    if params[:reason].blank?
      redirect_to @pool, alert: t(".missing_reason")
      return
    end

    CostPools::ReopenService.new(@pool).call!(reason: params[:reason])
    redirect_to @pool, notice: t(".reopened")
  rescue ArgumentError => e
    redirect_to @pool, alert: e.message
  end

  private

  def set_pool
    @pool = Current.account.cost_pools.find(params[:id])
    authorize @pool
  end

  def transition_error_message(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
  end
end
