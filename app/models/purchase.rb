class Purchase < ApplicationRecord
  include Monetizable

  SOURCES = %w[CardTrader Cardmarket Fiera Privato].freeze
  PRODUCT_TYPES = { "Sealed Box" => "sealed_box", "Pack" => "pack", "Single" => "single" }.freeze

  monetize :total_price, :shipping_cost, :tax

  has_many :inventory_items, dependent: :nullify

  validates :name, presence: true
  validates :currency, presence: true
  validates :total_price_cents, :shipping_cost_cents, :tax_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cardtrader_order_id, uniqueness: true, allow_nil: true

  def total_spent_cents
    total_price_cents.to_i + shipping_cost_cents.to_i + tax_cents.to_i
  end

  def allocated_cost_cents
    inventory_items.sum(:allocated_cost_cents)
  end

  def remaining_to_allocate_cents
    (total_price_cents.to_i + shipping_cost_cents.to_i) - allocated_cost_cents
  end
end
