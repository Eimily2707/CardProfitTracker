require "test_helper"

class InventoryItemTest < ActiveSupport::TestCase
  test "generate_public_ref returns a ref not already used by the account" do
    account = accounts(:acme)
    ref = InventoryItem.generate_public_ref(account)

    assert_match(/\AINV-[A-Z0-9]{8}\z/, ref)
  end

  test "public_ref is unique per account" do
    account = accounts(:acme)
    purchase = account.purchases.create!(channel: channels(:acme_fair), title: "Test", currency: "EUR")
    line = purchase.purchase_lines.create!(description: "A", kind: "single", intent: "sell", quantity: 1, unit_price_cents: 100)

    account.inventory_items.create!(
      purchase_line: line, kind: "single", name: "A", intent: "sell", status: "pending_arrival",
      cost_source: "purchase_split", acquired_on: Date.current, public_ref: "INV-DUPLICAT"
    )

    duplicate = account.inventory_items.new(
      purchase_line: line, kind: "single", name: "A", intent: "sell", status: "pending_arrival",
      cost_source: "purchase_split", acquired_on: Date.current, public_ref: "INV-DUPLICAT"
    )

    assert_not duplicate.valid?
  end
end
