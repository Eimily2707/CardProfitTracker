class CreatePendingOrderSyncs < ActiveRecord::Migration[8.1]
  # spec §8.7: coalesces multiple webhook notifications for the same order
  # within a short window into a single re-read, consumed by
  # Cardtrader::SyncOrderJob. Unique on (connection_id, ct_order_id) so
  # .request! is itself the coalescing operation - a second notification
  # while one is already queued/running is a no-op, not a new row.
  def change
    create_table :pending_order_syncs do |t|
      t.references :connection, null: false, foreign_key: { to_table: :cardtrader_connections }
      t.string :ct_order_id, null: false
      t.string :status, null: false, default: "queued"
      t.datetime :requested_at, null: false
      t.integer :attempts, null: false, default: 0

      t.timestamps
    end

    # Only one *active* (queued/running) sync per order - once it settles
    # (cancelled on success, failed after max attempts), a later webhook for
    # the same order can open a fresh row instead of being blocked forever.
    add_index :pending_order_syncs, %i[connection_id ct_order_id], unique: true, where: "status IN ('queued', 'running')",
              name: "index_pending_order_syncs_on_connection_and_order_while_active"
  end
end
