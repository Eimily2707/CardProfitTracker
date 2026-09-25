class InventoryItem < ApplicationRecord
  include Monetizable

  CONDITIONS = %w[NM EX GD LP PL PO].freeze
  LANGUAGES = %w[EN IT JP DE FR ES].freeze

  monetize :allocated_cost

  belongs_to :purchase, optional: true
  has_one :sale, dependent: :restrict_with_error

  enum :status, { in_stock: "in_stock", sold: "sold", personal_collection: "personal_collection" },
       default: "in_stock", validate: true

  validates :card_name, presence: true
  validates :condition, inclusion: { in: CONDITIONS }, allow_nil: true
  validates :allocated_cost_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
