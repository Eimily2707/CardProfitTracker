class CreateCtGames < ActiveRecord::Migration[8.1]
  # Global CardTrader catalog table (spec §4.3, §2.1): not tenant-scoped.
  def change
    create_table :ct_games do |t|
      t.integer :ct_id, null: false
      t.string :name, null: false
      t.string :display_name
      t.boolean :enabled, null: false, default: true
      t.datetime :synced_at

      t.timestamps
    end

    add_index :ct_games, :ct_id, unique: true
  end
end
