class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :account

  delegate :user, to: :session, allow_nil: true

  def membership
    return nil unless user && account

    @membership ||= user.memberships.find_by(account: account)
  end
end
