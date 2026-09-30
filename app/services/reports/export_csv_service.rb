require "csv"

module Reports
  # CSV exports for the M7 reporting UI (spec §6.7). Both reports read
  # already-computed/snapshotted figures (SaleLine#profit_base_cents,
  # InventoryItem#cost_base_cents) rather than recalculating anything.
  class ExportCsvService
    def initialize(account)
      @account = account
    end

    # Detailed sales report: one row per active SaleLine on a credited
    # order, with its profit breakdown.
    def sales_csv(from: nil, to: nil)
      CSV.generate do |csv|
        csv << %w[order_id channel sold_at credited_at line_description quantity
                   unit_price cost_snapshot allocated_charges profit currency]

        credited_orders(from: from, to: to).includes(:channel, sale_lines: :inventory_item).find_each do |order|
          order.sale_lines.select { |line| line.status == "active" }.each do |line|
            csv << [
              order.id, order.channel.name, order.sold_at, order.credited_at, line.description, line.quantity,
              line.unit_price.format, line.cost_snapshot&.format, line.allocated_net_charges&.format,
              line.profit_base&.format, account.base_currency
            ]
          end
        end
      end
    end

    # Current inventory valuation: every item not yet sold/written off, at
    # its tracked cost (spec §7.7's invested-capital figure, broken out per
    # item rather than just the total).
    def inventory_valuation_csv
      CSV.generate do |csv|
        csv << %w[public_ref name status kind acquired_on days_in_stock cost_base currency]

        account.inventory_items.where(status: %w[pending_arrival in_stock reserved]).order(:acquired_on).find_each do |item|
          csv << [
            item.public_ref, item.name, item.status, item.kind, item.acquired_on,
            (Date.current - item.acquired_on).to_i, item.cost_base.format, account.base_currency
          ]
        end
      end
    end

    private

    attr_reader :account

    def credited_orders(from: nil, to: nil)
      scope = account.sale_orders.where.not(credited_at: nil)
      scope = scope.where(credited_at: from.beginning_of_day..) if from
      scope = scope.where(credited_at: ..to.end_of_day) if to
      scope
    end
  end
end
