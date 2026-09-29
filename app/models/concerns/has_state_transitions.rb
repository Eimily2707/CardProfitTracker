module HasStateTransitions
  extend ActiveSupport::Concern

  included do
    has_many :state_transitions, as: :record, dependent: :destroy
  end

  # Records the append-only audit row (spec §2.4/§4.10) and assigns the new
  # status. Callers wrap this with their own side effects (item generation,
  # voiding, ...) in a transaction.
  def log_transition!(event:, to:, reason: nil)
    state_transitions.create!(
      from_state: status,
      to_state: to,
      event: event.to_s,
      source: "user",
      actor_user_id: Current.user&.id,
      reason: reason,
      occurred_at: Time.current
    )
    update!(status: to)
  end
end
