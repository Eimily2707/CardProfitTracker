class CreateCostPools < ActiveRecord::Migration[8.1]
  # spec §4.6/§5.3/§7.3: one pool per opened sealed/bulk_lot item, tracking
  # how its cost gets distributed across the items extracted from it.
  def change
    create_table :cost_pools do |t|
      t.references :account, null: false, foreign_key: true
      t.references :source_item, null: false, foreign_key: { to_table: :inventory_items }, index: { unique: true }
      t.bigint :total_base_cents, null: false, default: 0
      t.bigint :allocated_base_cents, null: false, default: 0
      t.bigint :written_off_base_cents, null: false, default: 0
      t.string :allocation_method, null: false, default: "equal"
      t.string :status, null: false, default: "open"

      t.timestamps
    end

    add_index :cost_pools, %i[account_id status]
  end
end
