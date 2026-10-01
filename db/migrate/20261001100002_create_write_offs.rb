class CreateWriteOffs < ActiveRecord::Migration[8.1]
  # spec §4.6: "almeno uno" tra cost_pool_id/inventory_item_id - enforced at
  # the model level (app-side business rule), not a DB CHECK constraint, to
  # match this app's established pattern for cross-column business rules.
  # This tranche only writes WriteOffs for a CostPool's unallocated residual
  # at close time (reason unallocated_residual/bulk_waste); the fuller
  # InventoryItem#write_off lifecycle (lost/damaged/stolen/counterfeit/...)
  # needs Shipment/Trade/Grading, which don't exist yet.
  def change
    create_table :write_offs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :cost_pool, foreign_key: true
      t.references :inventory_item, foreign_key: true
      t.bigint :amount_base_cents, null: false
      t.string :reason, null: false
      t.date :occurred_on, null: false

      t.timestamps
    end
  end
end
