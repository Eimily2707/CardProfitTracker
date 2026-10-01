module CostPools
  # Closes a pool (US-3.3): the residual must reach 0 first, via one of the
  # three options spec §7.3/US-3.3 lists.
  class CloseService
    ACTIONS = %w[distribute write_off absorb_bulk_lot].freeze

    def initialize(pool)
      @pool = pool
    end

    def call!(action:, reason: "unallocated_residual", occurred_on: Date.current)
      raise ArgumentError, "unknown close action" unless action.in?(ACTIONS)

      ApplicationRecord.transaction do
        case action
        when "distribute" then distribute!
        when "write_off" then write_off!(reason, occurred_on)
        when "absorb_bulk_lot" then absorb_bulk_lot!
        end

        pool.reload
        raise ArgumentError, "residual is not zero" unless pool.residual_base_cents.zero?

        pool.log_transition!(event: "close", to: "closed")
      end
    end

    private

    attr_reader :pool

    def distribute!
      CostPools::AllocationService.new(pool).recalculate!
    end

    def write_off!(reason, occurred_on)
      residual = pool.residual_base_cents
      raise ArgumentError, "no residual to write off" unless residual.positive?

      WriteOff.create!(account: pool.account, cost_pool: pool, amount_base_cents: residual, reason: reason, occurred_on: occurred_on)
      pool.update!(written_off_base_cents: pool.written_off_base_cents + residual)
    end

    def absorb_bulk_lot!
      residual = pool.residual_base_cents
      raise ArgumentError, "no residual to absorb" unless residual.positive?

      InventoryItem.create!(
        account: pool.account, origin_item: pool.source_item, cost_pool: pool, acquisition_type: "opening",
        public_ref: InventoryItem.generate_public_ref(pool.account), kind: "bulk_lot",
        name: "Residuo apertura #{pool.source_item.public_ref}", quantity: 1, intent: "sell", status: "in_stock",
        acquisition_cost_base_cents: residual, cost_base_cents: residual, cost_source: "pool_manual",
        acquired_on: pool.source_item.acquired_on
      )
      pool.update!(allocated_base_cents: pool.allocated_base_cents + residual)
    end
  end
end
