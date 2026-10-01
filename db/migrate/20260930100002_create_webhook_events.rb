class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  # spec §8.7/§5.8: a diagnostic log, not a source of state - no payload
  # stored, no unique constraint on the CardTrader event id (it changes on
  # every delivery attempt). Retention (30 days) is a scheduled cleanup
  # concern, not a schema one.
  def change
    create_table :webhook_events do |t|
      t.references :connection, null: false, foreign_key: { to_table: :cardtrader_connections }
      t.string :ct_object_id, null: false
      t.string :cause
      t.string :mode, null: false
      t.datetime :event_time, null: false
      t.string :status, null: false, default: "received"

      t.timestamps
    end
  end
end
