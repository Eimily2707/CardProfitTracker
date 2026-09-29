# Append-only audit trail for status changes (spec §2.4/§4.10). Written by
# HasStateTransitions#transition_to!; never updated or destroyed.
class StateTransition < ApplicationRecord
  SOURCES = %w[user system cardtrader_webhook cardtrader_import csv_import].freeze

  belongs_to :record, polymorphic: true
  belongs_to :actor_user, class_name: "User", optional: true

  validates :to_state, presence: true
  validates :event, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :occurred_at, presence: true
end
