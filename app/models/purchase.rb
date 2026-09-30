class Purchase < ApplicationRecord
  include TenantScoped
  include HasStateTransitions

  # spec §2.4: field-level audit trail alongside the status-transition log.
  has_paper_trail

  ORIGINS = %w[manual cardtrader_api csv].freeze
  FX_SOURCES = %w[ecb manual].freeze
  # Spec §5.1 has a fuller draft/ordered/in_transit/received/closed/
  # cancellation_requested/cancelled/lost lifecycle for shipping and
  # CardTrader import; this tranche only implements the manual-entry subset
  # it actually drives (US-2.1).
  STATUSES = %w[draft ordered received cancelled].freeze

  belongs_to :channel
  belongs_to :created_by, class_name: "User", optional: true
  has_many :purchase_lines, dependent: :destroy
  has_many :purchase_charges, dependent: :destroy
  has_many :inventory_items, through: :purchase_lines

  accepts_nested_attributes_for :purchase_lines, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :purchase_charges, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true
  validates :currency, presence: true, length: { is: 3 }
  validates :origin, inclusion: { in: ORIGINS }
  validates :fx_source, inclusion: { in: FX_SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :fx_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :fx_rate, presence: true, on: :confirm
  validate :has_at_least_one_active_line, on: :confirm

  before_destroy :prevent_destroying_confirmed_purchases

  monetize :subtotal_cents, :charges_total_cents, :total_cents, with_model_currency: :currency
  monetize :total_base_cents, with_model_currency: :account_base_currency, allow_nil: true

  def account_base_currency
    account.base_currency
  end

  # draft -> ordered (spec §5.1 confirm): fixes fx/totals, generates
  # pending_arrival items - one per unit, per line (§7.1).
  def confirm!
    raise_unless_status!("draft")

    transaction do
      freeze_totals!
      Purchases::ReceiveService.new(self).generate!(status: "pending_arrival")
      log_transition!(event: "confirm", to: "ordered")
    end
  end

  # draft -> received (spec §5.1 confirm_received): shortcut for an
  # in-person purchase (fair, shop) where the cards are already in hand.
  def confirm_received!
    raise_unless_status!("draft")

    transaction do
      freeze_totals!
      self.received_at ||= Time.current
      Purchases::ReceiveService.new(self).generate!(status: "in_stock")
      log_transition!(event: "confirm_received", to: "received")
    end
  end

  # ordered -> received (spec §5.1 receive): the already-generated
  # pending_arrival items become available for sale.
  def receive!
    raise_unless_status!("ordered")

    transaction do
      self.received_at ||= Time.current
      save!
      Purchases::ReceiveService.new(self).receive!
      log_transition!(event: "receive", to: "received")
    end
  end

  # ordered -> cancelled (spec §5.1 cancel): voids the pending items.
  def cancel!(reason: nil)
    raise_unless_status!("ordered")

    transaction do
      Purchases::ReceiveService.new(self).void!
      log_transition!(event: "cancel", to: "cancelled", reason: reason)
    end
  end

  private

  def raise_unless_status!(expected)
    return if status == expected

    raise ArgumentError, "cannot transition a #{status} purchase this way (expected #{expected})"
  end

  def has_at_least_one_active_line
    errors.add(:base, :no_active_lines) if purchase_lines.reject(&:marked_for_destruction?).none? { |line| line.status == "active" }
  end

  # spec §7.1: CostoCarico = Σ line_total + Σ charges - Σ refunds;
  # B_totale = round_half_up(CostoCarico × fx_rate), computed once; then the
  # largest-remainder method (§7.2) allocates B_totale across lines
  # (weighted by line_total) so the parts always sum back to B_totale.
  def freeze_totals!
    self.fx_rate ||= 1 if currency == account.base_currency

    active_lines = purchase_lines.select { |line| line.status == "active" }

    self.subtotal_cents = active_lines.sum(&:line_total_cents)
    self.charges_total_cents = purchase_charges.sum(&:amount_cents)
    self.refunds_total_cents ||= 0
    self.total_cents = subtotal_cents + charges_total_cents - refunds_total_cents

    save!(context: :confirm)

    self.fx_rate_date ||= (ordered_at || Time.current).to_date
    self.total_base_cents = (BigDecimal(total_cents) * fx_rate).round(0, BigDecimal::ROUND_HALF_UP).to_i

    landed_by_line = Allocation.allocate(total_base_cents, active_lines.map(&:line_total_cents))
    active_lines.each_with_index { |line, index| line.update!(landed_base_cents: landed_by_line[index]) }

    save!
  end

  def prevent_destroying_confirmed_purchases
    return if status == "draft"

    errors.add(:base, :only_drafts_can_be_deleted)
    throw :abort
  end
end
