# spec §4.15/§5.11 ("Da sistemare"): the app's to-do/notification system.
# Service objects open and close these when a condition appears/disappears;
# a person only snoozes or dismisses. Every kind from the spec is listed
# here so future tranches can plug into it without a schema change, but
# only import_failed/connection_invalid/credit_pending are actually opened
# by this tranche - the rest depend on features not built yet (unboxing,
# CT Zero, grading, trades, recurring expenses, label scanning).
class Task < ApplicationRecord
  include TenantScoped

  KINDS = %w[
    import_review link_proposal sale_conflict ct0_contestation open_cost_pool estimated_amount
    confirm_copy catch_up_failed credit_pending box_delivery_review import_failed connection_invalid
    grading_overdue pending_arrival_overdue recurring_expense
  ].freeze
  PRIORITIES = %w[high normal low].freeze
  STATUSES = %w[open snoozed resolved dismissed].freeze

  belongs_to :subject, polymorphic: true
  belongs_to :assignee, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }

  scope :open_or_snoozed, -> { where(status: %w[open snoozed]) }

  # spec §4.15: "unique con kind finché open" - the partial unique index on
  # (subject, kind) while open/snoozed makes repeated calls for the same
  # still-unresolved condition idempotent instead of piling up duplicates.
  def self.open_or_create!(kind:, subject:, account:, priority: "normal", metadata: {})
    existing = find_by(subject: subject, kind: kind, status: %w[open snoozed])
    return existing if existing

    create!(account: account, subject: subject, kind: kind, priority: priority, metadata: metadata)
  rescue ActiveRecord::RecordNotUnique
    find_by!(subject: subject, kind: kind, status: %w[open snoozed])
  end

  # spec §5.11: "resolved (automatico, quando la condizione sparisce)" -
  # called by the same service object that opened it, never by a person.
  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
  end

  def snooze!(until_at)
    update!(status: "snoozed", snoozed_until: until_at)
  end

  def unsnooze!
    update!(status: "open", snoozed_until: nil)
  end

  def dismiss!(reason = nil)
    update!(status: "dismissed", resolved_at: Time.current, resolution: reason)
  end
end
