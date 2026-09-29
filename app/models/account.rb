class Account < ApplicationRecord
  SUPPORTED_LOCALES = %w[it en fr es de].freeze
  ITEM_IDENTIFICATIONS = %w[fifo labels mixed].freeze
  CSV_SEPARATORS = %w[comma semicolon].freeze
  VAT_MODES = %w[gross net].freeze
  TRADE_VALUATION_METHODS = %w[carryover fair_value].freeze
  REBASE_STATUSES = %w[idle running failed].freeze

  # delete_all (not destroy): the owner-protection callbacks on Membership
  # exist to stop an *existing* account from ending up ownerless, which is
  # moot once the account itself is being torn down - and dependent:
  # :destroy would otherwise abort the cascade on the owner membership.
  has_many :memberships, dependent: :delete_all
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy

  validates :name, presence: true
  validates :base_currency, presence: true, length: { is: 3 }
  validates :country, presence: true, length: { is: 2 }
  validates :time_zone, presence: true
  validates :rebase_status, inclusion: { in: REBASE_STATUSES }
  validates :item_identification, inclusion: { in: ITEM_IDENTIFICATIONS }
  validates :csv_separator, inclusion: { in: CSV_SEPARATORS }
  validates :vat_mode, inclusion: { in: VAT_MODES }
  validates :trade_valuation_method, inclusion: { in: TRADE_VALUATION_METHODS }
  validates :default_locale, inclusion: { in: SUPPORTED_LOCALES }, allow_nil: true
  validates :label_threshold_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :time_zone_must_be_valid

  def owner
    memberships.find_by(role: "owner")&.user
  end

  private

  def time_zone_must_be_valid
    return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]

    errors.add(:time_zone, :invalid)
  end
end
