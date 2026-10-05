# Colored status/priority badges (UX polish tranche): a single generic
# component instead of ad hoc inline spans per view, mapped against the
# I18n enum scopes every status already has (enums.<scope>).
module StatusBadgeHelper
  COLOR_CLASSES = {
    gray: "bg-gray-100 text-gray-700",
    blue: "bg-blue-100 text-blue-700",
    green: "bg-green-100 text-green-700",
    amber: "bg-amber-100 text-amber-700",
    red: "bg-red-100 text-red-700",
    indigo: "bg-indigo-100 text-indigo-700",
    purple: "bg-purple-100 text-purple-700"
  }.freeze

  BADGE_COLORS = {
    "purchase.status" => { "draft" => :gray, "ordered" => :blue, "received" => :green, "cancelled" => :red },
    "sale_order.status" => {
      "draft" => :gray, "awaiting_payment" => :amber, "paid" => :blue,
      "shipped" => :indigo, "delivered" => :green, "cancelled" => :red
    },
    "inventory_item.status" => {
      "pending_arrival" => :amber, "in_stock" => :green, "reserved" => :amber, "sold" => :purple,
      "opened" => :indigo, "voided" => :red, "written_off" => :red
    },
    "cardtrader_connection.status" => {
      "pending_verification" => :amber, "active" => :green, "invalid" => :red, "disconnected" => :gray
    },
    "task.status" => { "open" => :amber, "snoozed" => :gray, "resolved" => :green, "dismissed" => :gray },
    "task.priority" => { "high" => :red, "normal" => :gray, "low" => :gray },
    "cost_pool.status" => { "open" => :amber, "allocated" => :blue, "closed" => :green },
    "expense.status" => { "draft" => :amber, "confirmed" => :green }
  }.freeze

  def status_badge(value, scope:)
    color = BADGE_COLORS.dig(scope, value.to_s) || :gray
    label = I18n.t(value, scope: "enums.#{scope}", default: value.to_s)

    tag.span(label, class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium #{COLOR_CLASSES.fetch(color)}")
  end
end
