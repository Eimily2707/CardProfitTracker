# spec §6.7 "M7 - Report e KPI": financial dashboard. Every role can view it
# (§2.1 "Consultare inventario e report"), so there's no dedicated Pundit
# policy - just requiring a membership, like the read-only actions on other
# controllers.
class DashboardController < ApplicationController
  PERIODS = %w[month quarter year custom].freeze

  def show
    return unless Current.account

    Tasks::CreditPendingCheck.new(Current.account).call!

    @period = PERIODS.include?(params[:period]) ? params[:period] : "month"
    @from, @to = period_range(@period)

    @calculator = Profits::CalculatorService.new(Current.account)
    @invested_capital = @calculator.invested_capital_base_cents
    @realized_profit = @calculator.realized_profit_base_cents(from: @from, to: @to)
    @expenses_total = @calculator.expenses_base_cents(from: @from, to: @to)
    @operating_profit = @calculator.operating_profit_base_cents(from: @from, to: @to)
    @cogs = @calculator.cogs_base_cents(from: @from, to: @to)
    @roi_percent = @calculator.roi_percent(from: @from, to: @to)
    @uncredited = @calculator.uncredited_summary
    @profit_by_channel = @calculator.profit_by_channel(from: @from, to: @to)
    @profit_by_game = @calculator.profit_by_game(from: @from, to: @to)
    @top_cards = @calculator.top_cards(from: @from, to: @to)
    @inventory_aging = @calculator.inventory_aging
    @channel_matrix = @calculator.purchase_channel_x_sale_channel_matrix(from: @from, to: @to)
    @monthly_trend = monthly_trend
  end

  private

  def period_range(period)
    today = Time.use_zone(Current.account.time_zone) { Time.zone.today }

    case period
    when "quarter"
      quarter_start = today.beginning_of_quarter
      [ quarter_start, quarter_start.end_of_quarter ]
    when "year"
      [ today.beginning_of_year, today.end_of_year ]
    when "custom"
      from = params[:from].presence && Date.parse(params[:from])
      to = params[:to].presence && Date.parse(params[:to])
      [ from, to ]
    else
      [ today.beginning_of_month, today.end_of_month ]
    end
  rescue ArgumentError
    [ today.beginning_of_month, today.end_of_month ]
  end

  # Last 6 calendar months' realized profit, for the trend chart.
  def monthly_trend
    today = Time.use_zone(Current.account.time_zone) { Time.zone.today }

    5.downto(0).map do |months_ago|
      month_start = (today - months_ago.months).beginning_of_month
      profit = @calculator.realized_profit_base_cents(from: month_start, to: month_start.end_of_month)
      { label: I18n.l(month_start, format: "%b %Y"), profit_base_cents: profit }
    end
  end
end
