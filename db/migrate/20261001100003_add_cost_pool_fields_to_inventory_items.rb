class AddCostPoolFieldsToInventoryItems < ActiveRecord::Migration[8.1]
  # Un-defers origin_item_id/cost_pool_id/reference_value_* from the original
  # inventory_items migration (spec §4.6) now that CostPool exists (§5.3).
  # origin_item_id is self-referential: the sealed/bulk_lot item an extracted
  # item came from (nesting - booster display -> booster -> cards - needs no
  # extra schema, just another row pointing at a now-opened item).
  def change
    add_reference :inventory_items, :origin_item, foreign_key: { to_table: :inventory_items }
    add_reference :inventory_items, :cost_pool, foreign_key: true
    add_column :inventory_items, :reference_value_cents, :bigint
    add_column :inventory_items, :reference_value_currency, :string, limit: 3
  end
end
