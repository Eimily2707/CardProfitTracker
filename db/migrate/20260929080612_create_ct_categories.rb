class CreateCtCategories < ActiveRecord::Migration[8.1]
  # Global CardTrader catalog table (spec §4.3, §2.1): not tenant-scoped.
  # ct_game_id stores CardTrader's own game id (matches ct_games.ct_id),
  # not a local foreign key - see CtCategory#ct_game.
  def change
    create_table :ct_categories do |t|
      t.integer :ct_id, null: false
      t.integer :ct_game_id, null: false
      t.string :name, null: false
      t.jsonb :properties, null: false, default: {}
      t.datetime :synced_at

      t.timestamps
    end

    add_index :ct_categories, :ct_id, unique: true
    add_index :ct_categories, :ct_game_id
  end
end
