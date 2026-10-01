module CostPools
  # Removing an extracted item frees its cost back into the pool's residual
  # (spec §5.3 "item aggiunti o rimossi, residuo != 0").
  class RemoveItemService
    def initialize(pool)
      @pool = pool
    end

    def call!(item)
      raise ArgumentError, "item is not in this pool" unless item.cost_pool_id == pool.id
      raise ArgumentError, "cannot remove a sold item" if item.status == "sold"

      ApplicationRecord.transaction do
        item.destroy!
        CostPools::AllocationService.new(pool).recalculate!
      end
    end

    private

    attr_reader :pool
  end
end
