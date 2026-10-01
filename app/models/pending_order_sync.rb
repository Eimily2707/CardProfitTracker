# spec §5.8/§8.7: coalesces webhook notifications for the same order into
# one re-read, consumed by Cardtrader::SyncOrderJob.
class PendingOrderSync < ApplicationRecord
  STATUSES = %w[queued running cancelled failed].freeze
  MAX_ATTEMPTS = 5

  belongs_to :connection, class_name: "CardtraderConnection", inverse_of: :pending_order_syncs

  validates :ct_order_id, presence: true
  validates :status, inclusion: { in: STATUSES }

  # The partial unique index on (connection_id, ct_order_id) while
  # queued/running *is* the coalescing: a second notification for an order
  # already pending just finds nothing new to insert.
  def self.request!(connection:, ct_order_id:)
    create!(connection: connection, ct_order_id: ct_order_id, requested_at: Time.current)
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def running!
    update!(status: "running")
  end

  def cancelled!
    update!(status: "cancelled")
  end

  # failed -> queued (retry) unless attempts are exhausted, per spec's
  # "max 5 tentativi, poi ordine in revisione". For a transient error
  # (rate limit, network) worth retrying.
  def failed!
    new_attempts = attempts + 1
    update!(attempts: new_attempts, status: new_attempts >= MAX_ATTEMPTS ? "failed" : "queued")
  end

  # A definitive error (bad token, order not found) won't fix itself on
  # retry - settle straight to failed instead of waiting out MAX_ATTEMPTS.
  def give_up!
    update!(status: "failed")
  end

  def exhausted?
    status == "failed"
  end
end
