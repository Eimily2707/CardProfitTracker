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
    @purchase.destroy
    redirect_to purchases_path, notice: "Acquisto eliminato.", status: :see_other
  end

  private

  def set_purchase
    @purchase = Purchase.find(params[:id])
  end

  def purchase_params
    params.require(:purchase).permit(
      :name, :source, :product_type, :purchase_date,
      :total_price, :shipping_cost, :tax, :currency,
      :via_cardtrader_zero, :cardtrader_order_id, :notes
    )
  end
end
