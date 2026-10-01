# spec §6.4 M4 - every role can browse/export inventory (§2.1 "Consultare
# inventario e report"); only operator-or-above can open a sealed/bulk_lot
# item (an unboxing is a financial action, not a read).
class InventoryItemsController < ApplicationController
  PER_PAGE = 25

  before_action :set_item, only: %i[show open]

  # US-4.1: combinable filters, sort, pagination, CSV export of the result.
  def index
    authorize InventoryItem
    @items = filtered_scope
    @page = [ params[:page].to_i, 1 ].max
    @total_count = @items.count
    @items = @items.includes(:ct_blueprint, :ct_game, :cost_pool).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)

    respond_to do |format|
      format.html
      format.csv do
        csv = Reports::ExportCsvService.new(Current.account).inventory_valuation_csv(scope: filtered_scope)
        send_data csv, filename: "inventario-#{Date.current.iso8601}.csv", type: "text/csv"
      end
    end
  end

  # US-4.3: timeline (PaperTrail versions - no state_transitions log exists
  # for InventoryItem status changes, see ReceiveService/FulfillSaleService),
  # cost chain (purchase -> sigillato -> item), vendite collegate.
  def show
    @versions = @item.versions.order(created_at: :desc)
  end

  def open
    authorize @item, :open?
    pool = CostPools::OpenService.new(@item).call!
    redirect_to cost_pool_path(pool), notice: t(".opened")
  rescue ArgumentError => e
    redirect_to @item, alert: e.message
  end

  private

  def set_item
    @item = Current.account.inventory_items.find(params[:id])
  end

  def filtered_scope
    scope = policy_scope(InventoryItem)
    scope = scope.where("name ILIKE :q OR expansion_name ILIKE :q", q: "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(kind: params[:kind]) if params[:kind].present?
    scope = scope.where(status: Array(params[:status])) if params[:status].present?
    scope = scope.where(location: params[:location]) if params[:location].present?
    scope = scope.where(ct_game_id: params[:ct_game_id]) if params[:ct_game_id].present?
    scope = scope.where(acquired_on: params[:from].to_date..) if params[:from].present?
    scope = scope.where(acquired_on: ..params[:to].to_date) if params[:to].present?
    scope = scope.where(cost_base_cents: params[:cost_min].to_i * 100..) if params[:cost_min].present?
    scope = scope.where(cost_base_cents: ..(params[:cost_max].to_i * 100)) if params[:cost_max].present?
    scope.order(sort_order)
  end

  SORTABLE_COLUMNS = %w[name acquired_on cost_base_cents status].freeze

  def sort_order
    column = params[:sort].presence_in(SORTABLE_COLUMNS) || "acquired_on"
    direction = params[:direction] == "asc" ? :asc : :desc
    { column => direction }
  end
end
