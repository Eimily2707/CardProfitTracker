module SalesHelper
  # In-stock items for the "select an inventory item" dropdown (spec §6.5
  # US-5.1), plus whichever item this line already points to (so editing a
  # confirmed line still shows its now-reserved/sold item).
  def available_inventory_items_for(line)
    account = line.sale_order&.account || Current.account
    scope = account.inventory_items.in_stock
    scope = scope.or(account.inventory_items.where(id: line.inventory_item_id)) if line.inventory_item_id.present?

    scope.order(:name)
  end
end
