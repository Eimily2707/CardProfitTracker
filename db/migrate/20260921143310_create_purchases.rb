class CreatePurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :purchases do |t|
      t.integer :cardtrader_order_id
      t.string :source
      t.boolean :via_cardtrader_zero, null: false, default: false
      t.string :product_type
      t.string :name, null: false
      t.date :purchase_date
      t.integer :total_price_cents
      t.integer :shipping_cost_cents
      t.integer :tax_cents
      t.string :currency, null: false, default: "EUR"
      t.text :notes

      t.timestamps
    end
    add_index :purchases, :cardtrader_order_id
  end
end
