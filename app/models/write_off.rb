# spec §4.6: a recorded loss, against a CostPool's unallocated residual or
# (future tranches) a single InventoryItem. Only the CostPool-residual path
# is wired up this tranche (reasons unallocated_residual/bulk_waste) - the
# fuller InventoryItem#write_off lifecycle needs Shipment/Trade/Grading.
class WriteOff < ApplicationRecord
  include TenantScoped

  REASONS = %w[unallocated_residual bulk_waste lost damaged stolen missing counterfeit retained_by_buyer other].freeze

  belongs_to :cost_pool, optional: true
  belongs_to :inventory_item, optional: true

  validates :amount_base_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, inclusion: { in: REASONS }
  validates :occurred_on, presence: true
  validate :belongs_to_a_pool_or_an_item

  monetize :amount_base_cents, as: "amount_base", with_model_currency: :account_base_currency

  def account_base_currency
    account.base_currency
  end

  private

  def belongs_to_a_pool_or_an_item
    errors.add(:base, :missing_target) if cost_pool.blank? && inventory_item.blank?
  end
end
