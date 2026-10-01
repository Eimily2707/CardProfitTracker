module CostPools
  # Reopens a closed pool (spec §5.3: "owner/admin, motivo; la svalutazione
  # di residuo si storna") - reverses any residual write-off so the pool's
  # residual becomes visible again instead of silently vanishing.
  class ReopenService
    def initialize(pool)
      @pool = pool
    end

    def call!(reason:)
      raise ArgumentError, "pool is not closed" unless pool.status == "closed"

      ApplicationRecord.transaction do
        residual_write_offs = pool.write_offs.where(reason: %w[unallocated_residual bulk_waste])
        reversed_total = residual_write_offs.sum(:amount_base_cents)
        residual_write_offs.destroy_all

        pool.update!(written_off_base_cents: pool.written_off_base_cents - reversed_total)
        pool.log_transition!(event: "reopen", to: "open", reason: reason)
      end
    end

    private

    attr_reader :pool
  end
end
