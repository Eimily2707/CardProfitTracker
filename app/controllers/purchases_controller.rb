class PurchasesController < ApplicationController
  before_action :set_purchase, only: %i[show edit update destroy]

  def index
    @purchases = Purchase.order(purchase_date: :desc, created_at: :desc)
  end

  def show
    @inventory_items = @purchase.inventory_items.order(created_at: :desc)
    @new_inventory_item = @purchase.inventory_items.new
  end

  def new
    @purchase = Purchase.new
  end

  def edit
  end

  def create
    @purchase = Purchase.new(purchase_params)

    if @purchase.save
      redirect_to @purchase, notice: "Acquisto registrato con successo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @purchase.update(purchase_params)
      redirect_to @purchase, notice: "Acquisto aggiornato con successo."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @purchase.destroy
      redirect_to purchases_path, notice: "Acquisto eliminato.", status: :see_other
    else
      redirect_to @purchase,
                  alert: "Impossibile eliminare l'acquisto: il prodotto sigillato risulta già venduto.",
                  status: :see_other
    end
  end

  # GET /purchases/import_from_cardtrader            -> lista degli ultimi ordini
  # GET /purchases/import_from_cardtrader?order_id=1 -> precompila il form "new"
  def import_from_cardtrader
    if params[:order_id].present?
      @purchase = Cardtrader::OrderImporter.new.build_purchase(order_id: params[:order_id])
      render :new
    else
      @recent_orders = Cardtrader::OrderImporter.new.recent_orders
    end
  rescue Cardtrader::Client::ApiError => e
    redirect_to params[:order_id].present? ? import_from_cardtrader_purchases_path : new_purchase_path,
                alert: "Impossibile importare da CardTrader: #{e.message}"
  end

  private

  def set_purchase
    @purchase = Purchase.find(params[:id])
  end

  def purchase_params
    params.require(:purchase).permit(
      :name, :source, :product_type, :purchase_date,
      :total_price, :shipping_cost, :tax, :currency,
      :via_cardtrader_zero, :cardtrader_order_id, :notes,
      :intent_type, :cardtrader_blueprint_id, :category_id, :blueprint_image_url
    )
  end
end
