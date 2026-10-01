class CreateCardtraderConnections < ActiveRecord::Migration[8.1]
  # spec §4.8/§5.7. Scoped down to the personal-token path (auth_method is
  # always "personal_token" this tranche - OAuth is explicitly deferred to
  # "Fase 5" by the spec itself, §8.10). bound_ct_user_id, refresh_token,
  # token_obtained_at, currency, last_reconciled_at and catch_up_status/from
  # are all OAuth- or reconciliation-after-downtime-only (§8.13, also
  # deferred) and are skipped along with those features.
  def change
    create_table :cardtrader_connections do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :auth_method, null: false, default: "personal_token"
      t.text :access_token, null: false
      t.text :shared_secret
      t.string :webhook_token, null: false
      t.datetime :webhook_registered_at
      t.string :status, null: false, default: "pending_verification"
      t.string :ct_username
      t.integer :ct_user_id
      t.datetime :last_verified_at
      t.text :last_error

      t.timestamps
    end

    add_index :cardtrader_connections, :webhook_token, unique: true
  end
end
