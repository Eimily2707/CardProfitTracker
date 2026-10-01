module CostPools
  # "Aggiunta rapida" (US-3.1): quantity copies of the same card/properties
  # create `quantity` separate single-unit items (InventoryItem#quantity is
  # only ever > 1 for kind bulk_lot), each tagged with origin_item_id/
  # cost_pool_id so the cost chain stays traceable (§4.6).
  class ExtractItemsService
    def initialize(pool)
      @pool = pool
    end

    def call!(name:, kind: "single", quantity: 1, expansion_name: nil, properties: {}, ct_blueprint_id: nil,
              intent: "sell", reference_value_cents: nil, manual_cost_cents: nil)
      raise ArgumentError, "pool is closed" if pool.status == "closed"

      # A manual per-item cost only means something under manual/hybrid (US-3.1
      # "costo opzionale in modalità manuale") - under equal/proportional every
      # unlocked item is recomputed by the formula regardless, so honoring it
      # here would just get silently overwritten one line below.
      manual_cost_cents = nil unless pool.allocation_method.in?(%w[manual hybrid])

      ApplicationRecord.transaction do
        blueprint = CtBlueprint.find_by(id: ct_blueprint_id)
        items = Array.new(quantity) { build_item(name, kind, expansion_name, properties, blueprint, intent, reference_value_cents, manual_cost_cents) }
        items.each(&:save!)
        CostPools::AllocationService.new(pool).recalculate!
        items
      end
    end

    private

    attr_reader :pool

    def build_item(name, kind, expansion_name, properties, blueprint, intent, reference_value_cents, manual_cost_cents)
      manual = manual_cost_cents.present?

      InventoryItem.new(
        account: pool.account, origin_item: pool.source_item, cost_pool: pool,
        acquisition_type: "opening", public_ref: InventoryItem.generate_public_ref(pool.account),
        ct_blueprint: blueprint, ct_game: blueprint&.ct_game,
        kind: kind, name: name, expansion_name: expansion_name, properties: properties,
        quantity: 1, intent: intent, status: "in_stock",
        acquisition_cost_base_cents: manual_cost_cents.to_i, cost_base_cents: manual_cost_cents.to_i,
        cost_source: manual ? "pool_manual" : "pool_equal",
        reference_value_cents: reference_value_cents, reference_value_currency: reference_value_cents.present? ? pool.account.base_currency : nil,
        acquired_on: pool.source_item.acquired_on
      )
    end
  end
end
