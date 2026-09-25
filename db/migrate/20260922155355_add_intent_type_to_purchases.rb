class AddIntentTypeToPurchases < ActiveRecord::Migration[8.1]
  def change
    add_column :purchases, :intent_type, :string, null: false, default: "crack_and_sell"
  end
end
