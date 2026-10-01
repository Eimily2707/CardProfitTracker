# frozen_string_literal: true

class CostPoolPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # Changing the allocation method, adding/removing extracted items, setting
  # a manual cost, and closing the pool (US-3.2/US-3.3).
  def update?
    operator_or_above? && record.status != "closed"
  end

  def close?
    operator_or_above? && record.status != "closed"
  end

  # spec §5.3: "owner/admin, motivo".
  def reopen?
    admin_or_owner? && record.status == "closed"
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
