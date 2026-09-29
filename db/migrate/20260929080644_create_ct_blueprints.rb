class CreateCtBlueprints < ActiveRecord::Migration[8.1]
  # Global CardTrader catalog table (spec §4.3, §2.1): not tenant-scoped.
  # ct_game_id/ct_category_id/ct_expansion_id store CardTrader's own ids
  # (matching the other ct_* tables' ct_id), not local foreign keys.
  def change
    create_table :ct_blueprints do |t|
      t.integer :ct_id, null: false
      t.string :name, null: false
      t.string :version
      t.integer :ct_game_id, null: false
      t.integer :ct_category_id, null: false
      t.integer :ct_expansion_id
      t.string :image_url
      t.jsonb :editable_properties, null: false, default: {}
      t.jsonb :fixed_properties, null: false, default: {}
      t.string :collector_number
      t.string :rarity
      t.string :scryfall_id
      t.integer :card_market_ids, array: true, null: false, default: []
      t.string :tcg_player_id
      # lower(unaccent(name + version + nome espansione + codice espansione)),
      # computed by the application on upsert (§4.3: unaccent isn't
      # immutable, so this can't be a stored generated column).
      t.text :search_text
      t.datetime :synced_at
      t.datetime :removed_at

      t.timestamps
    end

    add_index :ct_blueprints, :ct_id, unique: true
    add_index :ct_blueprints, :collector_number
    add_index :ct_blueprints, :scryfall_id
    add_index :ct_blueprints, :tcg_player_id
    add_index :ct_blueprints, %i[ct_expansion_id ct_category_id]
    add_index :ct_blueprints, :card_market_ids, using: :gin
    add_index :ct_blueprints, :search_text, using: :gin, opclass: :gin_trgm_ops, name: "index_ct_blueprints_on_search_text_trgm"
  end
end
