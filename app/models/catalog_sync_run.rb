class CatalogSyncRun < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze
  TRIGGERS = %w[schedule manual].freeze

  belongs_to :triggered_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :triggered_by, presence: true, if: -> { trigger == "manual" }

  broadcasts_refreshes

  def running!
    update!(status: "running", started_at: Time.current)
  end

  def completed!
    update!(status: "completed", finished_at: Time.current)
  end

  def failed!(message)
    update!(status: "failed", finished_at: Time.current, sync_errors: sync_errors + [ message ])
  end

  def record_expansion_progress!(blueprints_upserted: 0, blueprints_removed: 0)
    with_lock do
      increment(:expansions_done)
      increment(:blueprints_upserted, blueprints_upserted)
      increment(:blueprints_removed, blueprints_removed)
      save!
    end
  end
end
