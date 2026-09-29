class DropLegacyPreRewriteTables < ActiveRecord::Migration[8.1]
  # cardtrader_blueprints and inventory_items are leftovers from the
  # pre-multi-tenant-rewrite schema (Fase 1-5): their migrations were
  # deleted during the Tranche 1 cleanup without a matching db:rollback, so
  # the empty tables stayed in the dev database and in db/schema.rb ever
  # since, unnoticed until Tranche 3's real create_inventory_items collided
  # with the stale one. Both are empty and unreferenced by any current
  # model.
  def up
    drop_table :cardtrader_blueprints, if_exists: true
    drop_table :inventory_items, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
