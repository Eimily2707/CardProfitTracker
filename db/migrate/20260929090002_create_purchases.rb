class CreatePurchases < ActiveRecord::Migration[8.1]
  # Purchase header (spec §4.4). Scoped down to the manual-entry lifecycle
  # for this tranche (draft/ordered/received/cancelled - spec §5.1 has a
  # fuller in_transit/closed/cancellation_requested/lost lifecycle for
  # shipping and CardTrader import, deferred to a later tranche); the
  # CardTrader-import-only columns (external_order_id, external_state,
  # review_required, ...) are likewise deferred until that import feature
  # actually reads/writes them.
  def change
    create_table :purchases do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :origin, null: false, default: "manual"
      t.string :title, null: false
      t.string :seller_ref
      t.datetime :ordered_at
      t.datetime :received_at
      t.string :currency, limit: 3, null: false
      t.bigint :subtotal_cents, null: false, default: 0
      t.bigint :charges_total_cents, null: false, default: 0
      t.bigint :refunds_total_cents, null: false, default: 0
      t.bigint :total_cents, null: false, default: 0
      # nullable: a draft doesn't need a rate yet: only fixed at confirm
      # time (spec §5.1 "tasso fissato"), when Purchase#confirm! requires it.
      t.decimal :fx_rate, precision: 20, scale: 10
      t.date :fx_rate_date
      t.string :fx_source, null: false, default: "manual"
      t.bigint :total_base_cents
      t.string :status, null: false, default: "draft"
      t.text :notes

      t.timestamps
    end

    add_index :purchases, %i[account_id status]
  end
end
