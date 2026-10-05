# spec §4.12/§6.10 US-10.1: a general expense not tied to any purchase/sale
# order (fair table, shipping supplies, subscriptions, ...), subtracted
# from realized profit for the account's operating profit (§7.13).
class Expense < ApplicationRecord
  include TenantScoped
  include HasStateTransitions

  has_paper_trail

  RECURRENCES = %w[none monthly yearly].freeze
  FX_SOURCES = %w[ecb manual].freeze
  # spec §4.12: "Solo le confermate entrano nei report" - a fuller lifecycle
  # isn't called for, unlike Purchase/SaleOrder.
  STATUSES = %w[draft confirmed].freeze

  belongs_to :expense_category
  belongs_to :channel, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :source_expense, class_name: "Expense", optional: true
  has_one :successor, class_name: "Expense", foreign_key: :source_expense_id, inverse_of: :source_expense, dependent: :nullify
  has_one_attached :receipt

  validates :incurred_on, presence: true
  validates :currency, presence: true, length: { is: 3 }
  validates :amount_cents, numericality: { only_integer: true, other_than: 0 }
  validates :fx_source, inclusion: { in: FX_SOURCES }
  validates :recurrence, inclusion: { in: RECURRENCES }
  validates :status, inclusion: { in: STATUSES }
  validates :fx_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :fx_rate, presence: true, on: :confirm

  before_destroy :prevent_destroying_confirmed_expenses

  scope :draft, -> { where(status: "draft") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :recurring, -> { where.not(recurrence: "none") }

  monetize :amount_cents, with_model_currency: :currency
  monetize :amount_base_cents, with_model_currency: :account_base_currency, allow_nil: true

  def account_base_currency
    account.base_currency
  end

  # draft -> confirmed (spec §4.12): fixes the fx rate and converts to base
  # currency, same "freeze once" pattern as Purchase/SaleOrder.
  def confirm!
    raise_unless_status!("draft")

    transaction do
      self.fx_rate ||= 1 if currency == account.base_currency
      save!(context: :confirm)

      self.fx_rate_date ||= incurred_on
      self.amount_base_cents = (BigDecimal(amount_cents) * fx_rate).round(0, BigDecimal::ROUND_HALF_UP).to_i
      log_transition!(event: "confirm", to: "confirmed")
    end
  end

  private

  def raise_unless_status!(expected)
    return if status == expected

    raise ArgumentError, "cannot transition a #{status} expense this way (expected #{expected})"
  end

  def prevent_destroying_confirmed_expenses
    return if status == "draft"

    errors.add(:base, :only_drafts_can_be_deleted)
    throw :abort
  end
end
