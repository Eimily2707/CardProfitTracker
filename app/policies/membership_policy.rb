# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  # "Gestire membri e ruoli": owner can manage anyone; admin can manage
  # anyone except the owner (§2.1).
  def update?
    return false unless admin_or_owner?
    return true if owner?

    !record.owner?
  end

  def destroy?
    update?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
