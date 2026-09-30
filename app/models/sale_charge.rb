class SaleCharge < ApplicationRecord
  has_paper_trail

  KINDS = %w[shipping_charged platform_fee payment_fee repurchase_fee discount_given other_income other_expense].freeze
  DIRECTIONS = %w[income expense].freeze
  # spec §4.7: "Derivata dal kind, salvata per chiarezza nei report".
  KIND_DIRECTIONS = {
    "shipping_charged" => "income",
    "platform_fee" => "expense",
    "payment_fee" => "expense",
    "repurchase_fee" => "expense",
    "discount_given" => "expense",
    "other_income" => "income",
    "other_expense" => "expense"
  }.freeze

  belongs_to :sale_order

  validates :kind, inclusion: { in: KINDS }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :derive_direction_from_kind

  monetize :amount_cents, with_model_currency: :currency

  def currency
    sale_order&.currency || Money.default_currency.to_s
  end

  def income?
    direction == "income"
  end

  private

  def derive_direction_from_kind
    self.direction = KIND_DIRECTIONS[kind] if kind.present?
  end
end
