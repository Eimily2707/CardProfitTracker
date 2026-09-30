class CreateSaleOrders < ActiveRecord::Migration[8.1]
  # spec §4.7 (sale_orders), scoped down to the manual-entry + non-CT-Zero
  # CardTrader-import lifecycle (spec §5.5 has a fuller draft/awaiting_payment/
  # paid/shipped/delivered/completed/cancellation_requested/cancelled/lost/
  # returned lifecycle; this tranche implements the subset it actually drives).
  # CardTrader Zero (§8.5, hub-consolidated shipments), sale_bundles/lotti
  # (§7.16, US-5.8/5.11) and invoicing (§4.11) are deferred along with the
  # features that would use them.
  def change
    create_table :sale_orders do |t|
      t.references :account, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :origin, null: false, default: "manual"
      t.string :external_order_id
      t.string :external_order_code
      t.string :external_transaction_code
      t.string :external_state
      t.datetime :external_state_changed_at
      t.boolean :via_cardtrader_zero, null: false, default: false
      t.boolean :presale, null: false, default: false
      t.string :buyer_ref
      t.datetime :sold_at
      t.datetime :credited_at
      t.string :credit_source, null: false, default: "manual"
      t.string :currency, limit: 3, null: false
      t.bigint :items_subtotal_cents, null: false, default: 0
      t.bigint :income_total_cents, null: false, default: 0
      t.bigint :expense_total_cents, null: false, default: 0
      t.bigint :net_proceeds_cents, null: false, default: 0
      t.decimal :fx_rate, precision: 20, scale: 10
      t.date :fx_rate_date
      t.string :fx_source, null: false, default: "manual"
      t.bigint :net_proceeds_base_cents
      t.bigint :cogs_base_cents
      t.bigint :profit_base_cents
      t.string :status, null: false, default: "draft"
      t.boolean :review_required, null: false, default: false
      t.string :review_reasons, array: true, null: false, default: []
      t.string :payment_method
      t.text :notes

      t.timestamps
    end

    add_index :sale_orders, %i[account_id status]
    add_index :sale_orders, %i[account_id channel_id external_order_id], unique: true
  end
end
