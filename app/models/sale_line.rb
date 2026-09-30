class SaleLine < ApplicationRecord
  has_paper_trail

  # spec §4.7/§5.2: fuller list is active | awaiting_return | conflict |
  # cancelled | returned | lost - CT Zero disputes, returns and sale
  # conflicts (§8.5/§8.12) are deferred along with those features.
  STATUSES = %w[active cancelled].freeze
  # user_data_field/specific (label-based matching, M14) are deferred.
  MATCH_METHODS = %w[manual fifo].freeze

  belongs_to :sale_order
  belongs_to :inventory_item, optional: true
  belongs_to :ct_blueprint, optional: true

  validates :description, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :match_method, inclusion: { in: MATCH_METHODS }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # spec US-5.1: "Un item non può stare in due righe attive" - the DB partial
  # unique index is the hard guarantee; this gives a friendlier form error.
  validate :inventory_item_not_already_in_an_active_line

  scope :active, -> { where(status: "active") }

  monetize :unit_price_cents, with_model_currency: :currency
  monetize :cost_base_cents_snapshot, as: "cost_snapshot", with_model_currency: :account_base_currency, allow_nil: true
  monetize :allocated_net_charges_base_cents, as: "allocated_net_charges", with_model_currency: :account_base_currency, allow_nil: true

  def currency
    sale_order&.currency || Money.default_currency.to_s
  end

  def account_base_currency
    sale_order&.account&.base_currency || Money.default_currency.to_s
  end

  private

  def inventory_item_not_already_in_an_active_line
    return if inventory_item.blank? || status != "active"

    conflict = SaleLine.active.where(inventory_item_id: inventory_item_id).where.not(id: id)
    errors.add(:inventory_item, :already_in_an_active_line) if conflict.exists?
  end
end
