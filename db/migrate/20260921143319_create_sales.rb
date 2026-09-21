class CreateSales < ActiveRecord::Migration[8.1]
  def change
    create_table :sales do |t|
      t.references :inventory_item, null: false, foreign_key: true
      t.integer :cardtrader_order_id
      t.string :platform
      t.date :sale_date
      t.integer :sale_price_cents
      t.integer :platform_fees_cents
      t.integer :shipping_cost_cents
      t.integer :net_profit_cents

      t.timestamps
    end
    add_index :sales, :cardtrader_order_id
  end
end
