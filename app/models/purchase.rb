class Purchase < ApplicationRecord
  has_many :inventory_items, dependent: :nullify

  validates :name, presence: true
  validates :currency, presence: true
  validates :total_price_cents, :shipping_cost_cents, :tax_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cardtrader_order_id, uniqueness: true, allow_nil: true
end
