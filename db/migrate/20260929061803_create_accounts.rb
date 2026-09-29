class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :base_currency, limit: 3, null: false, default: "EUR"
      t.datetime :base_currency_changed_at
      t.string :rebase_status, null: false, default: "idle"
      t.string :time_zone, null: false, default: "UTC"
      t.string :default_locale
      t.string :item_identification, null: false, default: "fifo"
      t.bigint :label_threshold_cents
      t.string :csv_separator, null: false, default: "comma"
      t.string :country, limit: 2, null: false
      t.string :vat_mode, null: false, default: "gross"
      t.string :trade_valuation_method, null: false, default: "carryover"

      t.timestamps
    end
  end
end
