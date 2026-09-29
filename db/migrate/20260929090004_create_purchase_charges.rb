class CreatePurchaseCharges < ActiveRecord::Migration[8.1]
  # spec §4.4 (purchase_charges): accessory costs - shipping, duty, fees,
  # discounts - allocated across a purchase's lines (spec §7.1/§7.2). Not
  # directly tenant-scoped; always accessed through its purchase.
  def change
    create_table :purchase_charges do |t|
      t.references :purchase, null: false, foreign_key: true
      t.string :kind, null: false
      t.bigint :amount_cents, null: false

      t.timestamps
    end
  end
end
