# spec §4.8/§5.7: one CardTrader connection per account (personal API
# token this tranche - OAuth is spec-deferred to "Fase 5", §8.10). Owns the
# webhook_token/shared_secret Webhooks::CardtraderController verifies
# incoming requests against.
class CardtraderConnection < ApplicationRecord
  include TenantScoped

  AUTH_METHODS = %w[personal_token].freeze
  # spec §5.7 has a fuller lifecycle including suspended (OAuth-only, 403
  # from an app CardTrader disabled) - not reachable without OAuth.
  STATUSES = %w[pending_verification active invalid disconnected].freeze

  encrypts :access_token, :shared_secret

  has_many :webhook_events, foreign_key: :connection_id, inverse_of: :connection, dependent: :destroy
  has_many :pending_order_syncs, foreign_key: :connection_id, inverse_of: :connection, dependent: :destroy

  validates :access_token, presence: true
  validates :account_id, uniqueness: true
  validates :auth_method, inclusion: { in: AUTH_METHODS }
  validates :status, inclusion: { in: STATUSES }
  validates :webhook_token, presence: true, uniqueness: true

  before_validation :generate_webhook_token, on: :create

  scope :active, -> { where(status: "active") }

  # spec §5.7 (creation) -> pending_verification -> verify -> active
  # (GET /info succeeded). Real API call, not stubbed: a bad token needs to
  # surface here, not silently save as if it worked.
  def verify!(client: Cardtrader::Client.new(token: access_token))
    info = client.info
    update!(
      status: "active", ct_username: info["username"], ct_user_id: info["id"],
      shared_secret: info["shared_secret"] || shared_secret, last_verified_at: Time.current, last_error: nil
    )
  rescue Cardtrader::Client::ApiError => e
    update!(status: "invalid", last_error: e.message)
    raise
  end

  def mark_invalid!(reason)
    update!(status: "invalid", last_error: reason)
  end

  def disconnect!
    update!(status: "disconnected")
  end

  def register_webhook!
    update!(webhook_registered_at: Time.current)
  end

  private

  def generate_webhook_token
    self.webhook_token ||= SecureRandom.urlsafe_base64(32)
  end
end
