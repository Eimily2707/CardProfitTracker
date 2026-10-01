class AddCreditedAtIndexToSaleOrders < ActiveRecord::Migration[8.1]
  # Profits::CalculatorService#credited_orders (spec §7.4) filters
  # WHERE credited_at IS NOT NULL and ranges on it for every dashboard load
  # and CSV export - previously only account_id/status were indexed.
  def change
    add_index :sale_orders, %i[account_id credited_at]
  end
end
