# spec §4.12: preloaded per account, same system/custom split as Channel
# ("si possono rinominare o disattivare ma non eliminare" for the
# preloaded ones).
class ExpenseCategory < ApplicationRecord
  include TenantScoped

  SYSTEM_CATEGORIES = [
    { system_key: "fair", name: "Fiera" },
    { system_key: "shipping_supplies", name: "Materiali di spedizione" },
    { system_key: "sleeves", name: "Protezioni (bustine, toploader)" },
    { system_key: "subscriptions", name: "Abbonamenti" },
    { system_key: "software", name: "Software" },
    { system_key: "travel", name: "Viaggi" },
    { system_key: "other", name: "Altro" }
  ].freeze

  has_many :expenses, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }

  before_destroy :prevent_destroying_system_categories

  def system?
    system_key.present?
  end

  def self.seed_defaults_for!(account)
    SYSTEM_CATEGORIES.each do |attrs|
      account.expense_categories.find_or_create_by!(system_key: attrs[:system_key]) do |category|
        category.name = attrs[:name]
      end
    end
  end

  private

  def prevent_destroying_system_categories
    return unless system?

    errors.add(:base, :system_category_not_deletable)
    throw :abort
  end
end
