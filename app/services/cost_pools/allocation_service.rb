module CostPools
  # Implements the 4 distribution formulas of spec §7.3. Runs automatically
  # after every item is added/removed/updated (US-3.2); items already sold
  # are "costi bloccati" (§7.11) and never touched.
  class AllocationService
    class PoolExceededError < StandardError; end

    def initialize(pool)
      @pool = pool
    end

    def recalculate!
      ApplicationRecord.transaction do
        # .order (a query method) always re-queries, unlike a bare
        # `pool.extracted_items.to_a` - which would silently reuse an
        # already-loaded, now-stale cache when items were created through a
        # second ExtractItemsService call on this same pool instance. The
        # explicit order also makes the largest-remainder tie-break
        # deterministic (always the earliest-created item).
        items = pool.extracted_items.order(:id).to_a
        locked, unlocked = items.partition { |item| item.status == "sold" }
        locked_total = locked.sum(&:cost_base_cents)

        raise PoolExceededError, "locked item costs exceed the pool" if locked_total > pool.total_base_cents

        case pool.allocation_method
        when "manual"
          # Each item's cost is entered by hand (CostPoolItemsController#update);
          # nothing to auto-distribute, just refresh the cache below.
        when "equal"
          distribute_equally(unlocked, pool.total_base_cents - locked_total)
        when "proportional"
          distribute_proportionally(unlocked, pool.total_base_cents - locked_total)
        when "hybrid"
          distribute_hybrid(unlocked, pool.total_base_cents - locked_total)
        end

        pool.update!(allocated_base_cents: pool.extracted_items.sum(:cost_base_cents))
        pool.refresh_automatic_status!
      end
    end

    private

    attr_reader :pool

    def distribute_equally(unlocked, distributable)
      parts = Allocation.allocate(distributable, Array.new(unlocked.size, 1))
      unlocked.each_with_index { |item, index| item.update!(cost_base_cents: parts[index], cost_source: "pool_equal") }
    end

    def distribute_proportionally(unlocked, distributable)
      weights = unlocked.map { |item| item.reference_value_cents.to_i }
      parts = Allocation.allocate(distributable, weights)
      unlocked.each_with_index { |item, index| item.update!(cost_base_cents: parts[index], cost_source: "pool_proportional") }
    end

    # Manually-costed items keep their own figure; the rest of the pool
    # splits equally across whatever remains (spec §7.3 "hybrid").
    def distribute_hybrid(unlocked, distributable)
      manual, auto = unlocked.partition { |item| item.cost_source == "pool_manual" }
      manual_total = manual.sum(&:cost_base_cents)

      raise PoolExceededError, "manual item costs exceed the pool" if manual_total > distributable

      parts = Allocation.allocate(distributable - manual_total, Array.new(auto.size, 1))
      auto.each_with_index { |item, index| item.update!(cost_base_cents: parts[index], cost_source: "pool_equal") }
    end
  end
end
