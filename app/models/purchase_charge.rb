class PurchaseCharge < ApplicationRecord
  has_paper_trail

  KINDS = %w[shipping tax_duty platform_fee ct_zero_fee safeguard_fee payment_fee discount other].freeze

  belongs_to :purchase

  validates :kind, inclusion: { in: KINDS }
  validates :amount_cents, numericality: { only_integer: true }
  validate :amount_sign_matches_kind

  monetize :amount_cents, with_model_currency: :currency

  # purchase is nil for the blank PurchaseCharge.new used to render the
  # "add charge" <template> row - never actually submitted.
  def currency
    purchase&.currency || Money.default_currency.to_s
  end

  private

  # Spec §4.4: "negativo solo per discount".
  def amount_sign_matches_kind
    return if amount_cents.nil?
    return if kind == "discount" ? amount_cents <= 0 : amount_cents >= 0

    errors.add(:amount_cents, kind == "discount" ? :must_be_negative : :must_be_positive)
  end
end
