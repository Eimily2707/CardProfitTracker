# spec §5.8/§8.7: diagnostic log of every webhook delivery received, kept
# for 30 days, never a source of truth for order state - the actual sync
# happens by rereading GET /orders/:id (Cardtrader::SyncOrderJob).
class WebhookEvent < ApplicationRecord
  MODES = %w[live test].freeze
  STATUSES = %w[received rejected accepted test].freeze
  RETENTION = 30.days

  belongs_to :connection, class_name: "CardtraderConnection", inverse_of: :webhook_events

  validates :ct_object_id, presence: true
  validates :mode, inclusion: { in: MODES }
  validates :status, inclusion: { in: STATUSES }
  validates :event_time, presence: true

  scope :expired, -> { where(created_at: ...RETENTION.ago) }
end
