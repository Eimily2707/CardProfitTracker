# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # snooze!/dismiss!/unsnooze! (spec §5.11 - a person only snoozes or
  # dismisses; resolve! is always automatic, from a service object).
  def update?
    operator_or_above?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
