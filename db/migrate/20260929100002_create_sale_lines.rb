class CreateSaleLines < ActiveRecord::Migration[8.1]
  # spec §4.7. Not directly tenant-scoped - always accessed through its sale
  # order. ct_blueprint_id is a *local* FK (same clarification as
  # purchase_lines in Tranche 3). lot_group_id/price_allocation_method (lot
  # pricing, US-5.8/5.11) and vat_rate_bps/vat_cents (§4.11) are deferred.
  def change
    create_table :sale_lines do |t|
      t.references :sale_order, null: false, foreign_key: true
      t.references :inventory_item, foreign_key: true
      t.references :ct_blueprint, foreign_key: true
      t.string :external_order_item_id
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.bigint :unit_price_cents, null: false, default: 0
      t.string :match_method
      t.string :status, null: false, default: "active"
      t.bigint :cost_base_cents_snapshot
      t.bigint :allocated_net_charges_base_cents

      t.timestamps
    end

    # spec US-5.1: "Un item non può stare in due righe attive" (DB constraint).
    add_index :sale_lines, :inventory_item_id, unique: true, where: "status = 'active'",
              name: "index_sale_lines_on_inventory_item_id_when_active"
  end
end
