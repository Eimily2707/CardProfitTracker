class CreateCtExpansions < ActiveRecord::Migration[8.1]
  # Global CardTrader catalog table (spec §4.3, §2.1): not tenant-scoped.
  def change
    create_table :ct_expansions do |t|
      t.integer :ct_id, null: false
      t.integer :ct_game_id, null: false
      t.string :code
      t.string :name, null: false
      t.string :export_status, null: false, default: "ok"
      t.datetime :synced_at
      t.datetime :removed_at

      t.timestamps
    end

    add_index :ct_expansions, :ct_id, unique: true
    add_index :ct_expansions, :ct_game_id
  end
end
