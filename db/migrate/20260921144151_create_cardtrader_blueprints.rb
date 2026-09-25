class CreateCardtraderBlueprints < ActiveRecord::Migration[8.1]
  def change
    create_table :cardtrader_blueprints do |t|
      t.integer :cardtrader_id, null: false
      t.string :name, null: false
      t.string :expansion_name
      t.integer :game_id
      t.integer :category_id
      t.string :image_url
      t.string :scryfall_id
      t.string :cardmarket_id

      t.timestamps
    end
    add_index :cardtrader_blueprints, :cardtrader_id, unique: true
    add_index :cardtrader_blueprints, :name
  end
end
