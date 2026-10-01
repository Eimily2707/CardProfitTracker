module CostPools
  # US-3.2 "scelgo come distribuire il costo del pool" - switching method
  # triggers an immediate full recalculation under the new rule.
  class ChangeMethodService
    def initialize(pool)
      @pool = pool
    end

    def call!(method)
      raise ArgumentError, "unknown allocation method" unless method.in?(CostPool::ALLOCATION_METHODS)
      raise ArgumentError, "pool is closed" if pool.status == "closed"

      ApplicationRecord.transaction do
        pool.update!(allocation_method: method)
        CostPools::AllocationService.new(pool).recalculate!
      end
    end

    private

    attr_reader :pool
  end
end
