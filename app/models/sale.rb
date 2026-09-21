class Sale < ApplicationRecord
  belongs_to :inventory_item

  validates :sale_date, presence: true
  validates :sale_price_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :platform_fees_cents, :shipping_cost_cents, :net_profit_cents,
            numericality: { only_integer: true }, allow_nil: true
  validates :cardtrader_order_id, uniqueness: true, allow_nil: true
end
