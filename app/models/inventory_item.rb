class InventoryItem < ApplicationRecord
  include TenantScoped

  ACQUISITION_TYPES = %w[purchase opening opening_balance trade gift other].freeze
  KINDS = %w[single sealed bulk_lot accessory other].freeze
  INTENTS = %w[sell keep_sealed crack personal].freeze
  STATUSES = %w[pending_arrival in_stock voided written_off].freeze
  COST_SOURCES = %w[purchase_split pool_manual pool_equal pool_proportional manual].freeze

  belongs_to :purchase_line, optional: true
  belongs_to :ct_blueprint, optional: true
  belongs_to :ct_game, optional: true

  validates :public_ref, presence: true, uniqueness: { scope: :account_id }
  validates :acquisition_type, inclusion: { in: ACQUISITION_TYPES }
  validates :kind, inclusion: { in: KINDS }
  validates :intent, inclusion: { in: INTENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :cost_source, inclusion: { in: COST_SOURCES }
  validates :name, presence: true
  validates :acquired_on, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :acquisition_cost_base_cents, :cost_base_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :in_stock, -> { where(status: "in_stock") }
  scope :pending_arrival, -> { where(status: "pending_arrival") }

  monetize :acquisition_cost_base_cents, :cost_base_cents, with_model_currency: :account_base_currency

  def account_base_currency
    account.base_currency
  end

  def self.generate_public_ref(account)
    loop do
      candidate = "INV-#{SecureRandom.alphanumeric(8).upcase}"
      break candidate unless account.inventory_items.exists?(public_ref: candidate)
    end
  end
end
