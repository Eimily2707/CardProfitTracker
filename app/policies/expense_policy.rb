# frozen_string_literal: true

class ExpensePolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  def create?
    operator_or_above?
  end

  def update?
    operator_or_above? && record.status == "draft"
  end

  # confirm! (spec §2.1 "Confermare... record finanziari")
  def transition?
    operator_or_above?
  end

  def destroy?
    operator_or_above? && record.status == "draft"
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
