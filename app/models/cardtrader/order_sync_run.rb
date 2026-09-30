module Cardtrader
  # Tracks progress of one seller-order sync for an account's CardTrader
  # connection (spec §5.8 "ImportRequest"), mirroring CatalogSyncRun's
  # pattern - tenant-scoped here since orders belong to one account's
  # connection, unlike the shared global catalog.
  class OrderSyncRun < ApplicationRecord
    include TenantScoped

    # Rails infers "order_sync_runs" for a namespaced model by default
    # (the module isn't part of the table name unless table_name_prefix is
    # set) - the migration named it cardtrader_order_sync_runs instead, to
    # read unambiguously next to catalog_sync_runs in \d.
    self.table_name = "cardtrader_order_sync_runs"

    STATUSES = %w[queued running succeeded failed].freeze
    TRIGGERS = %w[schedule manual].freeze

    belongs_to :triggered_by, class_name: "User", optional: true

    validates :status, inclusion: { in: STATUSES }
    validates :trigger, inclusion: { in: TRIGGERS }
    validates :triggered_by, presence: true, if: -> { trigger == "manual" }

    broadcasts_refreshes

    def running!
      update!(status: "running", started_at: Time.current)
    end

    def succeeded!
      update!(status: "succeeded", finished_at: Time.current)
    end

    def failed!(message)
      update!(status: "failed", finished_at: Time.current, sync_errors: sync_errors + [ message ])
    end

    def record_order!(created: false, updated: false)
      with_lock do
        increment(:orders_created) if created
        increment(:orders_updated) if updated
        save!
      end
    end

    def record_failure!(message)
      with_lock do
        increment(:orders_failed)
        self.sync_errors = sync_errors + [ message ]
        save!
      end
    end
  end
end
