class CreatePurchaseLines < ActiveRecord::Migration[8.1]
  # spec §4.4. Not directly tenant-scoped (no account_id): always accessed
  # through its purchase, which is (spec's own clarification: ct_blueprint_id
  # is a *local* FK to ct_blueprints.id, unlike the ct_*-to-ct_* associations
  # in the catalog itself, which key off ct_id).
  def change
    create_table :purchase_lines do |t|
      t.references :purchase, null: false, foreign_key: true
      t.references :ct_blueprint, foreign_key: true
      t.string :description, null: false
      t.string :expansion_name
      t.string :kind, null: false
      t.string :intent, null: false
      t.integer :quantity, null: false, default: 1
      t.bigint :unit_price_cents, null: false, default: 0
      t.bigint :line_total_cents, null: false, default: 0
      t.jsonb :properties, null: false, default: {}
      t.string :status, null: false, default: "active"
      t.bigint :landed_base_cents

      t.timestamps
    end
  end
end
