class CreateExpenseCategories < ActiveRecord::Migration[8.1]
  # Preloaded per account (spec §4.12/§6.10), mirrors Channel's own
  # system/custom split: "si possono rinominare o disattivare ma non
  # eliminare" for the preloaded ones, custom ones are free to delete.
  def change
    create_table :expense_categories do |t|
      t.references :account, null: false, foreign_key: true
      t.string :system_key
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :expense_categories, %i[account_id name], unique: true
    add_index :expense_categories, %i[account_id system_key], unique: true
  end
end
