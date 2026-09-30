module Profits
  # Aggregates the account's financial KPIs (spec §6.7 "M7 - Report e KPI",
  # formulas in §7.4-§7.9, §7.13). Everything here is computed live, never
  # persisted - per the spec's own framing note at the top of §7 ("i
  # risultati sono calcolati dai service object e salvati come snapshot
  # solo dove indicato"): the only snapshots the spec actually calls for are
  # the per-order/per-line ones SaleOrder/SaleLine already store at
  # confirm_payment (Tranche 4). This service only reads those.
  #
  # KPIs that depend on features not yet built are intentionally not
  # implemented here: box recovery % and open pool residuals (§7.6, cost
  # pools/unboxing - deferred since Tranche 3), write-offs (§7.10 - no
  # WriteOff model yet), and general expenses (§7.13 - no Expense model yet,
  # M10). #operating_profit_base_cents below is realized profit alone,
  # without subtracting general expenses, for the same reason.
  class CalculatorService
    AGING_BUCKETS = [ (0..30), (31..90), (91..180), (181..Float::INFINITY) ].freeze

    def initialize(account)
      @account = account
    end

    # spec §7.7: cost of items not yet sold/written off. personal_collection
    # is excluded per spec, but isn't a status this app has reached yet.
    def invested_capital_base_cents
      account.inventory_items.where(status: %w[pending_arrival in_stock reserved]).sum(:cost_base_cents)
    end

    # spec §7.4/§6.7: recognized at credited_at, not at confirm_payment.
    def realized_profit_base_cents(from: nil, to: nil)
      credited_orders(from: from, to: to).sum(:profit_base_cents)
    end

    def cogs_base_cents(from: nil, to: nil)
      credited_orders(from: from, to: to).sum(:cogs_base_cents)
    end

    # spec §7.5: aggregate ROI is Σprofit/Σcogs, never the average of
    # per-order ROIs; nil (not zero) when there's no cost base to divide by.
    def roi_percent(from: nil, to: nil)
      cogs = cogs_base_cents(from: from, to: to)
      return nil if cogs.zero?

      (realized_profit_base_cents(from: from, to: to).to_f / cogs * 100).round(1)
    end

    # spec §6.7 "Venduto non accreditato": paid-or-further orders CardTrader
    # (or the user) hasn't confirmed the payout for yet.
    def uncredited_summary
      orders = account.sale_orders.where(status: %w[paid shipped delivered], credited_at: nil)
      { count: orders.count, net_proceeds_base_cents: orders.sum(:net_proceeds_base_cents) }
    end

    def profit_by_channel(from: nil, to: nil)
      credited_orders(from: from, to: to).joins(:channel).group("channels.name").sum(:profit_base_cents)
    end

    # spec §7.4 "Profitto per riga": profit_i = unit_price_base_i +
    # allocated_net_charges_base_cents_i - cost_base_cents_snapshot_i.
    # unit_price_base_i isn't stored (only the order-level totals are), so
    # it's converted here at the order's own frozen fx_rate - exact enough
    # for a breakdown report, matching the spec's own formula.
    def profit_by_game(from: nil, to: nil)
      line_profits(from: from, to: to).group_by { |row| row[:game_name] || "-" }
                                       .transform_values { |rows| rows.sum { |r| r[:profit_base_cents] } }
    end

    def profit_by_expansion(from: nil, to: nil)
      line_profits(from: from, to: to).group_by { |row| row[:expansion_name] || "-" }
                                       .transform_values { |rows| rows.sum { |r| r[:profit_base_cents] } }
    end

    # spec §6.4 KPI "Top carte per rendimento / volume di vendita".
    def top_cards(from: nil, to: nil, limit: 10)
      by_blueprint = line_profits(from: from, to: to).group_by { |row| row[:blueprint_name] || row[:description] }

      by_blueprint.map do |name, rows|
        { name: name, quantity: rows.sum { |r| r[:quantity] }, profit_base_cents: rows.sum { |r| r[:profit_base_cents] } }
      end.sort_by { |row| -row[:profit_base_cents] }.first(limit)
    end

    # spec §6.7 "Anzianità di magazzino": days since acquired_on for
    # currently in_stock items, bucketed.
    def inventory_aging
      today = Time.use_zone(account.time_zone) { Time.zone.today }

      buckets = AGING_BUCKETS.index_with { { count: 0, cost_base_cents: 0 } }
      account.inventory_items.in_stock.each do |item|
        days = (today - item.acquired_on).to_i
        bucket = AGING_BUCKETS.find { |range| range.cover?(days) }
        next unless bucket

        buckets[bucket][:count] += 1
        buckets[bucket][:cost_base_cents] += item.cost_base_cents
      end
      buckets
    end

    # spec §6.7 "Da dove compro, dove vendo": purchase channel x sale
    # channel matrix.
    def purchase_channel_x_sale_channel_matrix(from: nil, to: nil)
      rows = Hash.new { |h, k| h[k] = { quantity: 0, net_proceeds_base_cents: 0, profit_base_cents: 0 } }

      credited_orders(from: from, to: to).includes(sale_lines: { inventory_item: { purchase_line: { purchase: :channel } } }).find_each do |order|
        order.sale_lines.select { |line| line.status == "active" }.each do |line|
          purchase_channel = line.inventory_item&.purchase_line&.purchase&.channel&.name || "-"
          key = [ purchase_channel, order.channel.name ]
          rows[key][:quantity] += 1
          rows[key][:net_proceeds_base_cents] += line.unit_price_base_cents + line.allocated_net_charges_base_cents.to_i
          rows[key][:profit_base_cents] += line.profit_base_cents
        end
      end

      rows.map { |(purchase_channel, sale_channel), totals| { purchase_channel: purchase_channel, sale_channel: sale_channel, **totals } }
    end

    private

    attr_reader :account

    def credited_orders(from: nil, to: nil)
      scope = account.sale_orders.where.not(credited_at: nil)
      scope = scope.where(credited_at: from.beginning_of_day..) if from
      scope = scope.where(credited_at: ..to.end_of_day) if to
      scope
    end

    def line_profits(from: nil, to: nil)
      credited_orders(from: from, to: to)
        .includes(sale_lines: { inventory_item: { ct_blueprint: %i[ct_game ct_expansion] } })
        .flat_map do |order|
          order.sale_lines.select { |line| line.status == "active" }.map do |line|
            blueprint = line.inventory_item&.ct_blueprint
            {
              description: line.description,
              blueprint_name: blueprint&.name,
              game_name: blueprint&.ct_game&.display_name || blueprint&.ct_game&.name,
              expansion_name: blueprint&.ct_expansion&.name,
              quantity: line.quantity,
              profit_base_cents: line.profit_base_cents
            }
          end
        end
    end
  end
end
