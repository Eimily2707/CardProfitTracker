class CreateCatalogSyncRuns < ActiveRecord::Migration[8.1]
  # Global (spec §4.3, §9.6): not tenant-scoped. Tracks progress of a full
  # catalog sync, broadcast to the UI over Turbo Streams as it runs.
  def change
    create_table :catalog_sync_runs do |t|
      t.string :status, null: false, default: "pending"
      t.string :trigger, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :expansions_total, null: false, default: 0
      t.integer :expansions_done, null: false, default: 0
      t.integer :blueprints_upserted, null: false, default: 0
      t.integer :blueprints_removed, null: false, default: 0
      # Named sync_errors, not errors: a column literally named "errors"
      # collides with ActiveModel::Validations#errors and ActiveRecord
      # refuses to even define attribute methods for it (DangerousAttributeError).
      t.jsonb :sync_errors, null: false, default: []
      # Only set for trigger: "manual" (super-admin only, §9.6)
      t.references :triggered_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
