class CreateInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.references :purchase, null: true, foreign_key: true
      t.integer :cardtrader_blueprint_id
      t.integer :cardtrader_product_id
      t.integer :cardtrader_expansion_id
      t.integer :game_id
      t.integer :category_id
      t.string :scryfall_id
      t.string :cardmarket_id
      t.string :card_name, null: false
      t.string :set_name
      t.string :condition
      t.string :language
      t.boolean :is_foil, null: false, default: false
      t.string :image_url
      t.integer :allocated_cost_cents
      t.string :status, null: false, default: "in_stock"

      t.timestamps
    end
    add_index :inventory_items, :cardtrader_blueprint_id
    add_index :inventory_items, :cardtrader_product_id
  end
end
