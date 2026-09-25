class InventoryItemsController < ApplicationController
  before_action :set_inventory_item, only: :destroy

  def create
    @purchase = Purchase.find(params[:purchase_id])
    @inventory_item = @purchase.inventory_items.new(inventory_item_params)

    if @inventory_item.save
      redirect_to @purchase, notice: "Carta aggiunta all'inventario."
    else
      @inventory_items = @purchase.inventory_items.order(created_at: :desc)
      @new_inventory_item = @inventory_item
      render "purchases/show", status: :unprocessable_entity
    end
  end

  def destroy
    @purchase = @inventory_item.purchase
    @inventory_item.destroy
    redirect_to @purchase, notice: "Carta rimossa dall'inventario.", status: :see_other
  end

  private

  def set_inventory_item
    @inventory_item = InventoryItem.find(params[:id])
  end

  def inventory_item_params
    params.require(:inventory_item).permit(
      :cardtrader_blueprint_id, :card_name, :set_name, :image_url,
      :condition, :language, :is_foil, :allocated_cost
    )
  end
end
