module Sales
  # Moves the InventoryItem behind each of a SaleOrder's active lines through
  # the reserve -> sell -> release lifecycle (spec §5.5), keeping the two in
  # lockstep. Called from SaleOrder#submit!/confirm_payment!/cancel! rather
  # than containing transition logic itself.
  class FulfillSaleService
    def initialize(sale_order)
      @sale_order = sale_order
    end

    # draft -> awaiting_payment (submit!): in_stock -> reserved.
    def reserve!
      each_item do |item, _line|
        raise ArgumentError, "item #{item.public_ref} is not in_stock (#{item.status})" unless item.status == "in_stock"

        item.update!(status: "reserved")
      end
    end

    # draft/awaiting_payment -> paid (confirm_payment!): in_stock or
    # reserved -> sold, snapshotting the cost locked in at the sale.
    def mark_sold!
      each_item do |item, line|
        unless %w[in_stock reserved].include?(item.status)
          raise ArgumentError, "item #{item.public_ref} cannot be sold from #{item.status}"
        end

        item.update!(status: "sold")
        line.update!(cost_base_cents_snapshot: item.cost_base_cents)
      end
    end

    # awaiting_payment/paid -> cancelled (cancel!): reserved or sold ->
    # in_stock (spec §5.5 default disposition: return_to_stock).
    def release!
      each_item do |item, _line|
        next unless %w[reserved sold].include?(item.status)

        item.update!(status: "in_stock")
      end
    end

    private

    attr_reader :sale_order

    def each_item
      sale_order.sale_lines.select { |line| line.status == "active" }.each do |line|
        item = line.inventory_item
        yield item, line if item
      end
    end
  end
end
