class AddIsSealedProductToInventoryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inventory_items, :is_sealed_product, :boolean, null: false, default: false

    # Guarantees a purchase can have at most one auto-managed "sealed box" item,
    # even if something outside Purchase#sync_sealed_inventory_item creates one.
    add_index :inventory_items, :purchase_id,
              unique: true,
              where: "is_sealed_product = 1",
              name: "index_inventory_items_on_purchase_id_when_sealed"
  end
end
