# Nested under a CostPool (spec §6.3 US-3.1 "aggiunta rapida" / US-3.2
# manual cost entry). Authorized against the parent pool itself - these
# actions are really just CostPool#update in disguise.
class CostPoolItemsController < ApplicationController
  before_action :set_pool

  def create
    CostPools::ExtractItemsService.new(@pool).call!(**extract_params)
    redirect_to @pool, notice: t(".success")
  rescue ArgumentError, ActiveRecord::RecordInvalid, CostPools::AllocationService::PoolExceededError => e
    redirect_to @pool, alert: transition_error_message(e)
  end

  def update
    item = @pool.extracted_items.find(params[:id])
    CostPools::SetManualCostService.new(@pool).call!(item, money_to_cents(params[:cost]))
    redirect_to @pool, notice: t(".success")
  rescue ArgumentError, ActiveRecord::RecordInvalid, CostPools::AllocationService::PoolExceededError => e
    redirect_to @pool, alert: transition_error_message(e)
  end

  def destroy
    item = @pool.extracted_items.find(params[:id])
    CostPools::RemoveItemService.new(@pool).call!(item)
    redirect_to @pool, notice: t(".success")
  rescue ArgumentError => e
    redirect_to @pool, alert: e.message
  end

  private

  def set_pool
    @pool = Current.account.cost_pools.find(params[:cost_pool_id])
    authorize @pool, :update?
  end

  def extract_params
    permitted = params.permit(:name, :kind, :quantity, :expansion_name, :ct_blueprint_id, :intent,
                               :reference_value, :manual_cost, properties: %i[condition language foil])
    {
      name: permitted[:name], kind: permitted[:kind].presence || "single", quantity: permitted[:quantity].to_i.clamp(1, 100),
      expansion_name: permitted[:expansion_name], ct_blueprint_id: permitted[:ct_blueprint_id],
      intent: permitted[:intent].presence || "sell", properties: permitted[:properties]&.to_h || {},
      reference_value_cents: money_to_cents(permitted[:reference_value]),
      manual_cost_cents: money_to_cents(permitted[:manual_cost])
    }
  end

  # Params arrive as plain decimal strings (spec §7: money is always
  # {cents, currency}, never a float) - converted once at this boundary,
  # like every other money-entry form in the app.
  def money_to_cents(value)
    return nil if value.blank?

    Monetize.parse(value, @pool.account.base_currency).cents
  end

  def transition_error_message(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
  end
end
