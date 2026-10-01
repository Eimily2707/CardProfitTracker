class AddFilterIndexesToInventoryItems < ActiveRecord::Migration[8.1]
  # spec §6.4 US-4.1: the inventory list filters/sorts by kind and
  # acquired_on on every request - index them (status already is).
  def change
    add_index :inventory_items, %i[account_id kind]
    add_index :inventory_items, %i[account_id acquired_on]
  end
end
