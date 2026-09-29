module Purchases
  # Generates and updates the InventoryItem rows behind a Purchase's active
  # lines, keeping the sum of item costs exactly equal to each line's
  # landed_base_cents (spec §7.1/§7.2 - no rounding drift). Called from
  # Purchase#confirm!/confirm_received! (generate!) and #receive!/#cancel!
  # (receive!/void!).
  class ReceiveService
    def initialize(purchase)
      @purchase = purchase
    end

    # Idempotent per line (spec US-2.1 "riconfermare... non crea
    # duplicati"): a line that already has items is left alone.
    def generate!(status:)
      purchase.purchase_lines.select { |line| line.status == "active" }.each do |line|
        next if line.inventory_items.exists?

        if line.kind == "bulk_lot"
          create_item!(line, status: status, quantity: line.quantity, cost_cents: line.landed_base_cents.to_i)
        else
          per_item_costs = Allocation.allocate(line.landed_base_cents.to_i, Array.new(line.quantity, 1))
          line.quantity.times { |index| create_item!(line, status: status, quantity: 1, cost_cents: per_item_costs[index]) }
        end
      end
    end

    def receive!
      purchase.inventory_items.pending_arrival.update_all(status: "in_stock", updated_at: Time.current)
    end

    def void!
      purchase.inventory_items.pending_arrival.update_all(status: "voided", updated_at: Time.current)
    end

    private

    attr_reader :purchase

    def create_item!(line, status:, quantity:, cost_cents:)
      InventoryItem.create!(
        account: purchase.account,
        purchase_line: line,
        acquisition_type: "purchase",
        public_ref: InventoryItem.generate_public_ref(purchase.account),
        ct_blueprint: line.ct_blueprint,
        ct_game: line.ct_blueprint&.ct_game,
        kind: line.kind,
        name: line.description,
        expansion_name: line.expansion_name,
        properties: line.properties,
        quantity: quantity,
        intent: line.intent,
        status: status,
        acquisition_cost_base_cents: cost_cents,
        cost_base_cents: cost_cents,
        cost_source: "purchase_split",
        acquired_on: (purchase.received_at || purchase.ordered_at || Time.current).to_date
      )
    end
  end
end
