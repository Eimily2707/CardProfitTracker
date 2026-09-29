class User < ApplicationRecord
  SUPPORTED_LOCALES = %w[it en fr es de].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :accounts, through: :memberships

  encrypts :otp_secret

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :locale, inclusion: { in: SUPPORTED_LOCALES }, allow_nil: true
  validates :time_zone, presence: true
  validate :time_zone_must_be_valid

  def confirmed?
    confirmed_at.present?
  end

  private

  def time_zone_must_be_valid
    return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]

    errors.add(:time_zone, :invalid)
  end
end
