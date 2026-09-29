class Channel < ApplicationRecord
  include TenantScoped

  KINDS = %w[marketplace physical_shop online_shop fair private social other].freeze
  USAGES = %w[purchase sale both].freeze
  CREDIT_TIMINGS = %w[immediate manual].freeze

  # Preloaded per account (spec §4.7): "si possono rinominare o disattivare
  # ma non eliminare" - custom (system_key: nil) channels the user adds
  # themselves can be deleted freely.
  SYSTEM_CHANNELS = [
    { system_key: "cardtrader", name: "CardTrader", kind: "marketplace", credit_timing: "manual", allows_bundles: false },
    { system_key: "cardmarket", name: "Cardmarket", kind: "marketplace", credit_timing: "manual" },
    { system_key: "tcgplayer", name: "TCGplayer", kind: "marketplace", credit_timing: "manual" },
    { system_key: "ebay", name: "eBay", kind: "marketplace", credit_timing: "manual" },
    { system_key: "amazon", name: "Amazon", kind: "marketplace", credit_timing: "manual" },
    { system_key: "vinted", name: "Vinted", kind: "marketplace", credit_timing: "manual" },
    { system_key: "physical_shop", name: "Negozio fisico", kind: "physical_shop", credit_timing: "immediate" },
    { system_key: "online_shop", name: "Negozio online", kind: "online_shop", credit_timing: "manual" },
    { system_key: "fair", name: "Fiera", kind: "fair", credit_timing: "immediate" },
    { system_key: "other", name: "Altro", kind: "other", credit_timing: "manual" }
  ].freeze

  has_many :purchases, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }
  validates :usage, inclusion: { in: USAGES }
  validates :credit_timing, inclusion: { in: CREDIT_TIMINGS }
  validates :default_currency, length: { is: 3 }, allow_nil: true

  scope :active, -> { where(active: true) }

  before_destroy :prevent_destroying_system_channels

  def system?
    system_key.present?
  end

  def self.seed_defaults_for!(account)
    SYSTEM_CHANNELS.each do |attrs|
      account.channels.find_or_create_by!(system_key: attrs[:system_key]) do |channel|
        channel.assign_attributes(usage: "both", **attrs)
      end
    end
  end

  private

  def prevent_destroying_system_channels
    return unless system?

    errors.add(:base, :system_channel_not_deletable)
    throw :abort
  end
end
