class SaleOrder < ApplicationRecord
  include TenantScoped
  include HasStateTransitions

  # spec §2.4: field-level audit trail alongside the status-transition log.
  has_paper_trail

  ORIGINS = %w[manual cardtrader_api csv].freeze
  CREDIT_SOURCES = %w[cardtrader immediate manual].freeze
  FX_SOURCES = %w[ecb manual].freeze
  PAYMENT_METHODS = %w[cash card bank_transfer paypal platform other].freeze
  # spec §5.5 has a fuller draft/awaiting_payment/paid/shipped/delivered/
  # completed/cancellation_requested/cancelled/lost/returned lifecycle; this
  # tranche implements the subset US-5.1/5.2 actually drive. completed
  # (manual or N-day auto-close), lost/recover (write-offs) and returned
  # (returns) are deferred along with the features that would use them.
  STATUSES = %w[draft awaiting_payment paid shipped delivered cancelled].freeze

  belongs_to :channel
  belongs_to :created_by, class_name: "User", optional: true
  has_many :sale_lines, dependent: :destroy
  has_many :sale_charges, dependent: :destroy
  has_many :inventory_items, through: :sale_lines

  accepts_nested_attributes_for :sale_lines, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sale_charges, allow_destroy: true, reject_if: :all_blank

  validates :currency, presence: true, length: { is: 3 }
  validates :origin, inclusion: { in: ORIGINS }
  validates :credit_source, inclusion: { in: CREDIT_SOURCES }
  validates :fx_source, inclusion: { in: FX_SOURCES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }
  validates :fx_rate, numericality: { greater_than: 0 }, allow_nil: true
  validates :fx_rate, presence: true, on: :confirm
  validate :has_at_least_one_active_line, on: :confirm

  before_destroy :prevent_destroying_confirmed_sale_orders

  monetize :items_subtotal_cents, :income_total_cents, :expense_total_cents, :net_proceeds_cents,
           with_model_currency: :currency
  monetize :net_proceeds_base_cents, :cogs_base_cents, :profit_base_cents,
           with_model_currency: :account_base_currency, allow_nil: true

  def account_base_currency
    account.base_currency
  end

  # draft -> awaiting_payment (spec §5.5 submit): items reserved, none sold
  # yet - used when a buyer commits before paying (e.g. an unconfirmed
  # CardTrader order).
  def submit!
    raise_unless_status!("draft")

    transaction do
      Sales::FulfillSaleService.new(self).reserve!
      log_transition!(event: "submit", to: "awaiting_payment")
    end
  end

  # draft/awaiting_payment -> paid (spec §5.5 confirm_payment): freezes
  # totals/fx, locks each line's cost snapshot, items -> sold. Revenue only
  # counts in reports once credited (§7.4, not built - credited_at is
  # tracked but nothing reads it yet).
  def confirm_payment!
    raise_unless_status!(%w[draft awaiting_payment])

    transaction do
      freeze_totals!
      Sales::FulfillSaleService.new(self).mark_sold!
      self.sold_at ||= Time.current
      save!
      log_transition!(event: "confirm_payment", to: "paid")
    end
  end

  # paid -> shipped (spec §5.5 ship). No dedicated Shipment record this
  # tranche (§5.6 deferred) - tracked directly on the order.
  def ship!
    raise_unless_status!("paid")
    log_transition!(event: "ship", to: "shipped")
  end

  # shipped -> delivered (spec §5.5 deliver).
  def deliver!
    raise_unless_status!("shipped")
    log_transition!(event: "deliver", to: "delivered")
  end

  # draft/awaiting_payment/paid -> cancelled (spec §5.5 cancel - draft added
  # so a CardTrader order already cancelled before we ever confirmed it
  # locally can still be recorded as such): items return to stock (default
  # disposition; §5.4's fuller adjustment/disposition choice is deferred).
  def cancel!(reason: nil)
    raise_unless_status!(%w[draft awaiting_payment paid])

    transaction do
      Sales::FulfillSaleService.new(self).release!
      log_transition!(event: "cancel", to: "cancelled", reason: reason)
    end
  end

  # Not a status change (spec §5.5: "non è uno stato ma un evento"), just
  # records when the channel actually paid out the seller.
  def mark_credited!
    raise ArgumentError, "cannot credit a #{status} order" unless %w[paid shipped delivered].include?(status)

    transaction do
      update!(credited_at: Time.current)
      log_transition!(event: "mark_credited", to: status)
    end
  end

  # Advances the local status per the spec §8.4 mapping, logging every
  # external state received even when the local status doesn't move (§2.4).
  # request_for_cancel/lost/via_cardtrader_zero and any state this tranche
  # doesn't implement (§5.5's fuller lifecycle) fall back to review_required
  # instead of guessing; so does a foreign-currency order with no fx_rate
  # yet (the ECB rate job, §4.9, is deferred - same limitation as Purchase).
  def apply_external_state!(external_state)
    transaction do
      from_status = status
      target = resolve_external_state_target(external_state)

      if target.nil?
        flag_for_review!("external_state_#{external_state}") unless NO_OP_EXTERNAL_STATES.include?(external_state)
      elsif review_required?
        # already flagged (e.g. a line with no matching inventory item, spec
        # US-5.2 "con tutte le righe abbinate... la vendita è confermata in
        # automatico") - stays put until a person resolves it manually.
      elsif target != status && sale_lines.none? { |line| line.status == "active" }
        flag_for_review!("no_active_lines")
      elsif target != status && currency != account.base_currency && fx_rate.blank?
        flag_for_review!("fx_rate_missing")
      elsif target != status
        advance_to_external_target!(target)
      end

      update!(external_state: external_state, external_state_changed_at: Time.current)
      state_transitions.create!(
        from_state: from_status, to_state: status, event: "external_sync", source: "cardtrader_import",
        reason: "CardTrader state: #{external_state}", occurred_at: Time.current
      )
    end
  end

  private

  NO_OP_EXTERNAL_STATES = %w[pending closed].freeze
  CANCEL_EXTERNAL_STATES = %w[cancelled canceled].freeze
  REVIEW_ONLY_EXTERNAL_STATES = %w[request_for_cancel lost].freeze
  EXTERNAL_STATE_TARGETS = { "hub_pending" => "paid", "paid" => "paid", "sent" => "shipped", "arrived" => "delivered", "done" => "delivered" }.freeze

  def resolve_external_state_target(external_state)
    return "cancelled" if CANCEL_EXTERNAL_STATES.include?(external_state)
    return nil if REVIEW_ONLY_EXTERNAL_STATES.include?(external_state) || NO_OP_EXTERNAL_STATES.include?(external_state)

    EXTERNAL_STATE_TARGETS[external_state]
  end

  def flag_for_review!(reason)
    update!(review_required: true, review_reasons: (review_reasons + [ reason ]).uniq)
  end

  def advance_to_external_target!(target)
    case target
    when "cancelled"
      cancel! if %w[draft awaiting_payment paid].include?(status)
    when "paid"
      confirm_payment! if %w[draft awaiting_payment].include?(status)
    when "shipped"
      confirm_payment! if %w[draft awaiting_payment].include?(status)
      ship! if status == "paid"
    when "delivered"
      confirm_payment! if %w[draft awaiting_payment].include?(status)
      ship! if status == "paid"
      deliver! if status == "shipped"
    end
  end

  def raise_unless_status!(expected)
    return if Array(expected).include?(status)

    raise ArgumentError, "cannot transition a #{status} sale order this way (expected #{Array(expected).join(' or ')})"
  end

  def has_at_least_one_active_line
    errors.add(:base, :no_active_lines) if sale_lines.reject(&:marked_for_destruction?).none? { |line| line.status == "active" }
  end

  # spec §7.1-style: convert once, then largest-remainder allocate (§7.2) so
  # per-line figures always sum back to the order totals exactly.
  def freeze_totals!
    self.fx_rate ||= 1 if currency == account.base_currency

    active_lines = sale_lines.select { |line| line.status == "active" }

    self.items_subtotal_cents = active_lines.sum { |line| line.unit_price_cents * line.quantity }
    self.income_total_cents = sale_charges.select(&:income?).sum(&:amount_cents)
    self.expense_total_cents = sale_charges.reject(&:income?).sum(&:amount_cents)
    self.net_proceeds_cents = items_subtotal_cents + income_total_cents - expense_total_cents

    save!(context: :confirm)

    self.fx_rate_date ||= (sold_at || Time.current).to_date
    self.net_proceeds_base_cents = (BigDecimal(net_proceeds_cents) * fx_rate).round(0, BigDecimal::ROUND_HALF_UP).to_i
    self.cogs_base_cents = active_lines.sum { |line| line.inventory_item&.cost_base_cents.to_i }
    self.profit_base_cents = net_proceeds_base_cents - cogs_base_cents

    # allocated_net_charges_base_cents is each line's share of the order's
    # net charges (shipping income minus fees), in base currency - not
    # counting the line's own sale price, which is already known per line.
    net_charges_base_cents = (BigDecimal(income_total_cents - expense_total_cents) * fx_rate).round(0, BigDecimal::ROUND_HALF_UP).to_i
    weights = active_lines.map { |line| line.unit_price_cents * line.quantity }
    allocated = Allocation.allocate(net_charges_base_cents, weights)
    active_lines.each_with_index { |line, index| line.update!(allocated_net_charges_base_cents: allocated[index]) }

    save!
  end

  def prevent_destroying_confirmed_sale_orders
    return if status == "draft"

    errors.add(:base, :only_drafts_can_be_deleted)
    throw :abort
  end
end
