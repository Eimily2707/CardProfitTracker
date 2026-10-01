module CostPools
  # US-3.2 manual per-item cost entry - only meaningful under the "manual"
  # and "hybrid" allocation methods (equal/proportional compute every item's
  # cost themselves). Overrunning the pool is caught by CostPool's own
  # residual-never-negative validation when AllocationService refreshes the
  # cache, or - for hybrid - by AllocationService's own explicit check
  # before it tries to split the (now negative) remainder across auto items.
  class SetManualCostService
    def initialize(pool)
      @pool = pool
    end

    def call!(item, cost_cents)
      raise ArgumentError, "item is not in this pool" unless item.cost_pool_id == pool.id
      raise ArgumentError, "item cost is locked (sold)" if item.status == "sold"
      raise ArgumentError, "manual cost entry requires the manual or hybrid method" unless pool.allocation_method.in?(%w[manual hybrid])

      ApplicationRecord.transaction do
        item.update!(cost_base_cents: cost_cents, cost_source: "pool_manual")
        CostPools::AllocationService.new(pool).recalculate!
      end
    end

    private

    attr_reader :pool
  end
end
