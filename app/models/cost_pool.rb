# spec §4.6/§5.3/§7.3: tracks how the cost of an opened sealed/bulk_lot
# InventoryItem (source_item) gets distributed across the items extracted
# from it. Only close/reopen are real user-triggered events (logged via
# HasStateTransitions); the open<->allocated flip is automatic bookkeeping
# driven by CostPools::AllocationService, not a loggable action.
class CostPool < ApplicationRecord
  include TenantScoped
  include HasStateTransitions

  has_paper_trail

  ALLOCATION_METHODS = %w[manual equal proportional hybrid].freeze
  STATUSES = %w[open allocated closed].freeze

  belongs_to :source_item, class_name: "InventoryItem"
  validates :source_item_id, uniqueness: true
  has_many :extracted_items, class_name: "InventoryItem", foreign_key: :cost_pool_id, inverse_of: :cost_pool
  has_many :write_offs, dependent: :destroy

  validates :total_base_cents, :allocated_base_cents, :written_off_base_cents,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :allocation_method, inclusion: { in: ALLOCATION_METHODS }
  validates :status, inclusion: { in: STATUSES }
  validate :residual_never_negative

  monetize :total_base_cents, :allocated_base_cents, :written_off_base_cents, with_model_currency: :account_base_currency

  def account_base_currency
    account.base_currency
  end

  def residual_base_cents
    total_base_cents - allocated_base_cents - written_off_base_cents
  end

  # Not a DB column, so `monetize` can't generate this - wrapped by hand.
  def residual_base
    Money.new(residual_base_cents, account_base_currency)
  end

  # §7.6 "Recupero del box": net proceeds of sold descendants / pool cost.
  def recovery_percent
    return nil if total_base_cents.zero?

    sold_net_proceeds = extracted_items.includes(sale_lines: :sale_order).sum do |item|
      item.sale_lines.select { |line| line.status == "active" && line.sale_order.credited_at.present? }
          .sum { |line| line.unit_price_base_cents.to_i + line.allocated_net_charges_base_cents.to_i }
    end

    (sold_net_proceeds.to_f / total_base_cents * 100).round(1)
  end

  # Automatic bookkeeping flip (spec §5.3) - not a user event, so not logged
  # via HasStateTransitions. Closed pools only move via #close!/#reopen!.
  def refresh_automatic_status!
    return if status == "closed"

    update!(status: residual_base_cents.zero? ? "allocated" : "open")
  end

  private

  def residual_never_negative
    return if total_base_cents.nil? || allocated_base_cents.nil? || written_off_base_cents.nil?

    errors.add(:base, :residual_negative) if residual_base_cents.negative?
  end
end
