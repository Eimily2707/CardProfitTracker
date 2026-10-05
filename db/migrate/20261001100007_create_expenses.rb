class CreateExpenses < ActiveRecord::Migration[8.1]
  # spec §4.12/§6.10/§7.13: general expenses not tied to a purchase/sale
  # order, subtracted from realized profit for the account's operating
  # profit (and, per channel, from that channel's own profitability).
  # vat_rate_bps/vat_cents are deferred along with the rest of M9 (IVA),
  # which isn't built yet - same reasoning as Purchase/SaleLine already
  # deferring them.
  def change
    create_table :expenses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :expense_category, null: false, foreign_key: true
      t.references :channel, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      # Self-referential: the recurring expense this one's draft was
      # generated from, so the generator can tell which series already has
      # a pending/confirmed successor and never double-generates one.
      t.references :source_expense, foreign_key: { to_table: :expenses }
      t.string :description
      t.string :supplier_ref
      t.date :incurred_on, null: false
      t.string :currency, limit: 3, null: false
      t.bigint :amount_cents, null: false
      t.decimal :fx_rate, precision: 20, scale: 10
      t.date :fx_rate_date
      t.string :fx_source, null: false, default: "manual"
      t.bigint :amount_base_cents
      t.string :recurrence, null: false, default: "none"
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :expenses, %i[account_id status]
    add_index :expenses, %i[account_id incurred_on]
  end
end
