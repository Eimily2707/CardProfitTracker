require "test_helper"

# spec §2.4: "Audit a livello di campo (gem paper_trail)... ogni modifica
# finanziaria o cambio di stato traccia l'utente responsabile (whodunnit),
# la data/ora e i valori precedenti/nuovi." One representative model per
# tranche (Purchase from Tranche 3, SaleOrder from Tranche 4) is enough to
# prove the PaperTrail wiring itself works - has_paper_trail is declared
# identically on every other listed model (PurchaseLine, PurchaseCharge,
# InventoryItem, SaleLine, SaleCharge).
class PaperTrailTraceabilityTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:acme)
  end

  test "creating and updating a Purchase records whodunnit and the changeset" do
    PaperTrail.request(whodunnit: users(:elena).id.to_s) do
      purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Original title", currency: "EUR")

      assert_equal 1, purchase.versions.count
      assert_equal users(:elena).id.to_s, purchase.versions.last.whodunnit

      purchase.update!(title: "Updated title")

      update_version = purchase.versions.last
      assert_equal "update", update_version.event
      assert_equal users(:elena).id.to_s, update_version.whodunnit
      assert_equal [ "Original title", "Updated title" ], update_version.changeset["title"]
    end
  end

  test "destroying a draft Purchase records the deletion with whodunnit" do
    PaperTrail.request(whodunnit: users(:elena).id.to_s) do
      purchase = @account.purchases.create!(channel: channels(:acme_fair), title: "Draft", currency: "EUR")
      purchase.destroy!

      destroy_version = PaperTrail::Version.where(item_type: "Purchase", item_id: purchase.id, event: "destroy").last
      assert_equal users(:elena).id.to_s, destroy_version.whodunnit
    end
  end

  test "confirming payment on a SaleOrder is itself tracked as an update" do
    item = @account.inventory_items.create!(
      kind: "single", name: "Card", intent: "sell", status: "in_stock", cost_source: "manual",
      acquired_on: Date.current, public_ref: InventoryItem.generate_public_ref(@account),
      acquisition_cost_base_cents: 100, cost_base_cents: 100
    )

    PaperTrail.request(whodunnit: users(:elena).id.to_s) do
      sale = @account.sale_orders.create!(channel: channels(:acme_cardtrader), currency: "EUR")
      sale.sale_lines.create!(inventory_item: item, description: item.name, unit_price_cents: 500)

      sale.confirm_payment!

      status_version = sale.versions.where(event: "update").last
      assert_equal %w[draft paid], status_version.changeset["status"]
      assert_equal users(:elena).id.to_s, status_version.whodunnit
    end
  end
end
