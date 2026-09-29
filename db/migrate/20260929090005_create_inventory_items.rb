class CreateInventoryItems < ActiveRecord::Migration[8.1]
  # spec §4.6, scoped down to the purchase-origin subset this tranche needs:
  # acquisition_type is always "purchase" for now (opening/opening_balance/
  # trade/gift arrive with the unboxing and trade-in tranches), and status
  # only ever reaches pending_arrival/in_stock/voided/written_off (the fuller
  # spec §5.4 lifecycle - listed/reserved/sold/... - belongs to the sales
  # tranche). cost_pool_id, sale_bundle_id, labeled, cost_locked_at,
  # reference_value_*, listed_channel_ids and ct_product_id are deferred
  # along with the features that actually populate them.
  def change
    create_table :inventory_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :purchase_line, foreign_key: true
      t.string :acquisition_type, null: false, default: "purchase"
      t.string :public_ref, null: false
      t.references :ct_blueprint, foreign_key: true
      t.references :ct_game, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.string :expansion_name
      t.jsonb :properties, null: false, default: {}
      t.integer :quantity, null: false, default: 1
      t.string :intent, null: false
      t.string :status, null: false, default: "pending_arrival"
      t.bigint :acquisition_cost_base_cents, null: false, default: 0
      t.bigint :cost_base_cents, null: false, default: 0
      t.boolean :cost_estimated, null: false, default: false
      t.string :cost_source, null: false
      t.date :acquired_on, null: false
      t.string :location

      t.timestamps
    end

    add_index :inventory_items, %i[account_id public_ref], unique: true
    add_index :inventory_items, %i[account_id status]
  end
end
