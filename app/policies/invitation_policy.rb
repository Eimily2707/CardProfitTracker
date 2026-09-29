# frozen_string_literal: true

class InvitationPolicy < ApplicationPolicy
  def index?
    admin_or_owner?
  end

  def create?
    admin_or_owner?
  end

  def destroy?
    admin_or_owner?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
