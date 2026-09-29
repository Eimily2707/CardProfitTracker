class PurchaseLine < ApplicationRecord
  KINDS = %w[single sealed bulk_lot accessory other].freeze
  INTENTS = %w[sell keep_sealed crack personal].freeze
  STATUSES = %w[active cancelled missing_refunded].freeze
  # spec §4.5 (properties.condition); the full PropertyNormalizer (per-game
  # key mapping from CardTrader's API) is deferred - manual entry only uses
  # this fixed list this tranche.
  CONDITIONS = %w[mint near_mint slightly_played moderately_played played heavily_played poor].freeze

  belongs_to :purchase
  belongs_to :ct_blueprint, optional: true
  has_many :inventory_items, dependent: :nullify

  validates :description, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :intent, inclusion: { in: INTENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :compute_line_total
  before_validation :snapshot_from_blueprint, on: :create

  scope :active, -> { where(status: "active") }

  monetize :unit_price_cents, :line_total_cents, with_model_currency: :currency

  # Spec §4.6: default is one item per unit, even for bulk - "bulk_lot" is
  # the exception where the whole line becomes a single unsorted item.
  def item_count
    kind == "bulk_lot" ? 1 : quantity
  end

  # purchase is nil for the blank PurchaseLine.new used to render the
  # "add line" <template> row - never actually submitted, so any currency
  # is fine for that display-only case.
  def currency
    purchase&.currency || Money.default_currency.to_s
  end

  private

  def compute_line_total
    self.line_total_cents = unit_price_cents.to_i * quantity.to_i
  end

  def snapshot_from_blueprint
    return if ct_blueprint.blank?

    self.description ||= ct_blueprint.name
    self.expansion_name ||= ct_blueprint.ct_expansion&.name
  end
end
