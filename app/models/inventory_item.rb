class InventoryItem < ApplicationRecord
  include TenantScoped

  # spec §2.4: field-level audit trail (status/cost changes, in particular -
  # "il tracciamento della storia del pezzo per il successivo calcolo delle
  # marginalità").
  has_paper_trail

  ACQUISITION_TYPES = %w[purchase opening opening_balance trade gift other].freeze
  KINDS = %w[single sealed bulk_lot accessory other].freeze
  INTENTS = %w[sell keep_sealed crack personal].freeze
  # spec §5.4 has a fuller lifecycle (listed, at_grading, personal_collection,
  # traded, returning, ...); reserved/sold/opened are the subset this
  # tranche's Sales and Unboxing (M3) flows actually drive. opened is
  # terminal, like the spec's own list.
  STATUSES = %w[pending_arrival in_stock reserved sold opened voided written_off].freeze
  COST_SOURCES = %w[purchase_split pool_manual pool_equal pool_proportional manual].freeze

  belongs_to :purchase_line, optional: true
  belongs_to :ct_blueprint, optional: true
  belongs_to :ct_game, optional: true
  belongs_to :origin_item, class_name: "InventoryItem", optional: true
  belongs_to :cost_pool, optional: true
  has_many :sale_lines, dependent: :nullify
  has_many :extracted_items, class_name: "InventoryItem", foreign_key: :origin_item_id, inverse_of: :origin_item, dependent: :nullify
  has_many :write_offs, dependent: :nullify

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
  scope :reserved, -> { where(status: "reserved") }
  scope :sold, -> { where(status: "sold") }
  scope :opened, -> { where(status: "opened") }
  scope :openable, -> { where(status: "in_stock", kind: %w[sealed bulk_lot]) }

  monetize :acquisition_cost_base_cents, :cost_base_cents, with_model_currency: :account_base_currency
  monetize :reference_value_cents, with_model_currency: :reference_value_currency, allow_nil: true

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
