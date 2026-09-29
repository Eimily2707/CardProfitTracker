require "digest"

class Invitation < ApplicationRecord
  include TenantScoped

  ROLES = %w[admin operator viewer].freeze
  EXPIRATION_PERIOD = 7.days

  belongs_to :invited_by, class_name: "User", optional: true

  before_validation :assign_expiration, on: :create
  before_validation :assign_token, on: :create

  validates :email, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :expires_at, presence: true
  validates :token_digest, presence: true, uniqueness: true

  # Only set right after #assign_token runs in this same process/request -
  # the raw value is never persisted, only its digest is (token_digest).
  attr_reader :token

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?

    find_by(token_digest: digest(raw_token))
  end

  def expired?
    expires_at.past?
  end

  def accepted?
    accepted_at.present?
  end

  def accept!
    update!(accepted_at: Time.current)
  end

  private

  def assign_expiration
    self.expires_at ||= EXPIRATION_PERIOD.from_now
  end

  def assign_token
    return if token_digest.present?

    raw = SecureRandom.urlsafe_base64(32)
    @token = raw
    self.token_digest = self.class.digest(raw)
  end
end
