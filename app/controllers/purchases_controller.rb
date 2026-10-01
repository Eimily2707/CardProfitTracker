class PurchasesController < ApplicationController
  before_action :set_purchase, only: %i[show edit update destroy confirm confirm_received receive cancel]

  def index
    authorize Purchase
    @purchases = policy_scope(Purchase).includes(:channel).order(created_at: :desc)
  end

  def show
  end

  def new
    @purchase = Current.account.purchases.new(currency: Current.account.base_currency)
    authorize @purchase
    @purchase.purchase_lines.build
  end

  def create
    @purchase = Current.account.purchases.new(purchase_params)
    @purchase.created_by = Current.user
    authorize @purchase

    if @purchase.save
      redirect_to @purchase, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @purchase.purchase_lines.build if @purchase.purchase_lines.empty?
  end

  def update
    if @purchase.update(purchase_params)
      redirect_to @purchase, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @purchase.destroy
      redirect_to purchases_path, notice: t(".success"), status: :see_other
    else
      redirect_to @purchase, alert: @purchase.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def confirm
    authorize @purchase, :transition?
    @purchase.confirm!
    redirect_to @purchase, notice: t(".confirmed")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @purchase, alert: transition_error_message(e)
  end

  def confirm_received
    authorize @purchase, :transition?
    @purchase.confirm_received!
    redirect_to @purchase, notice: t(".received")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @purchase, alert: transition_error_message(e)
  end

  def receive
    authorize @purchase, :transition?
    @purchase.receive!
    redirect_to @purchase, notice: t(".received")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @purchase, alert: transition_error_message(e)
  end

  def cancel
    authorize @purchase, :transition?
    @purchase.cancel!
    redirect_to @purchase, notice: t(".cancelled")
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to @purchase, alert: transition_error_message(e)
  end

  private

  def set_purchase
    @purchase = find_purchase_scope.find(params[:id])
    # confirm/confirm_received/receive/cancel authorize explicitly against
    # :transition? in their own action - Pundit's implicit action-name
    # lookup would otherwise look for confirm?/receive?/... methods that
    # don't exist.
    authorize @purchase unless %w[confirm confirm_received receive cancel].include?(action_name)
  end

  # show iterates every line's inventory_items.count and reads charges/channel -
  # eager load them there to avoid a query per line/charge (index already does
  # its own .includes(:channel)).
  def find_purchase_scope
    return Current.account.purchases unless action_name == "show"

    Current.account.purchases.includes(:channel, :purchase_charges, purchase_lines: :inventory_items)
  end

  def transition_error_message(error)
    error.is_a?(ActiveRecord::RecordInvalid) ? error.record.errors.full_messages.to_sentence : error.message
  end

  def purchase_params
    params.require(:purchase).permit(
      :channel_id, :title, :seller_ref, :ordered_at, :currency, :fx_rate, :notes,
      purchase_lines_attributes: [
        :id, :ct_blueprint_id, :description, :expansion_name, :kind, :intent, :quantity, :unit_price, :_destroy,
        properties: %i[condition language foil]
      ],
      purchase_charges_attributes: %i[id kind amount _destroy]
    )
  end
end
