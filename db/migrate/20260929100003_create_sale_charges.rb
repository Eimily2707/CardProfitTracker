class CreateSaleCharges < ActiveRecord::Migration[8.1]
  # spec §4.7 (sale_charges): shipping charged to the buyer (income) and
  # platform/payment fees (expense) - allocated across a sale's lines the
  # same way purchase_charges are (spec §7.1/§7.2, Allocation module).
  def change
    create_table :sale_charges do |t|
      t.references :sale_order, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :direction, null: false
      t.bigint :amount_cents, null: false

      t.timestamps
    end
  end
end
