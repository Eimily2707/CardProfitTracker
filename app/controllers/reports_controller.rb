# spec §6.7: CSV exports. Every role can view/export reports (§2.1
# "Consultare inventario e report"), so - like DashboardController - there's
# no dedicated Pundit policy, just requiring a membership.
class ReportsController < ApplicationController
  def sales
    from = params[:from].presence && Date.parse(params[:from])
    to = params[:to].presence && Date.parse(params[:to])

    csv = Reports::ExportCsvService.new(Current.account).sales_csv(from: from, to: to)
    send_data csv, filename: "vendite-#{Date.current.iso8601}.csv", type: "text/csv"
  rescue ArgumentError
    redirect_to root_path, alert: t(".invalid_dates")
  end

  def inventory
    csv = Reports::ExportCsvService.new(Current.account).inventory_valuation_csv
    send_data csv, filename: "inventario-#{Date.current.iso8601}.csv", type: "text/csv"
  end
end
