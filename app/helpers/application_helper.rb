module ApplicationHelper
  def format_money(cents, currency: "EUR")
    unit = currency == "EUR" ? "€" : "#{currency} "
    number_to_currency((cents || 0) / 100.0, unit: unit, format: "%u%n", precision: 2, delimiter: ".", separator: ",")
  end

  SOURCE_BADGE_CLASSES = {
    "CardTrader" => "bg-blue-100 text-blue-800",
    "Cardmarket" => "bg-orange-100 text-orange-800",
    "Fiera" => "bg-green-100 text-green-800",
    "Privato" => "bg-gray-100 text-gray-800"
  }.freeze

  def source_badge_classes(source)
    SOURCE_BADGE_CLASSES.fetch(source, "bg-gray-100 text-gray-800")
  end
end
