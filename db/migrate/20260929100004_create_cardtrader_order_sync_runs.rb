class CreateCardtraderOrderSyncRuns < ActiveRecord::Migration[8.1]
  # spec §5.8 (ImportRequest): tracks progress of a seller-order sync for one
  # account's CardTrader connection - unlike CatalogSyncRun (global, shared
  # catalog), this is tenant-scoped since each account syncs its own orders.
  def change
    create_table :cardtrader_order_sync_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :triggered_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "queued"
      t.string :trigger, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :orders_created, null: false, default: 0
      t.integer :orders_updated, null: false, default: 0
      t.integer :orders_failed, null: false, default: 0
      t.jsonb :sync_errors, null: false, default: []

      t.timestamps
    end
  end
end
