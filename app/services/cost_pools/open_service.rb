module CostPools
  # Opens a sealed/bulk_lot item (spec §5.4 "open", US-3.1): creates its
  # CostPool with the item's own cost as the pool total, and moves the item
  # to the terminal "opened" status.
  class OpenService
    def initialize(item)
      @item = item
    end

    def call!
      raise ArgumentError, "item is not in_stock" unless item.status == "in_stock"
      raise ArgumentError, "item is not sealed or bulk_lot" unless item.kind.in?(%w[sealed bulk_lot])
      raise ArgumentError, "item already has a cost pool" if CostPool.exists?(source_item_id: item.id)

      ApplicationRecord.transaction do
        pool = CostPool.create!(
          account: item.account, source_item: item, total_base_cents: item.cost_base_cents, allocation_method: "equal"
        )
        item.update!(status: "opened")
        pool
      end
    end

    private

    attr_reader :item
  end
end
