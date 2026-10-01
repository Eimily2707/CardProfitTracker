# frozen_string_literal: true

# spec §2.1: "Collegare/scollegare CardTrader" - owner and admin only.
class CardtraderConnectionPolicy < ApplicationPolicy
  def show?
    admin_or_owner?
  end

  def create?
    admin_or_owner?
  end

  def update?
    admin_or_owner?
  end

  def destroy?
    admin_or_owner?
  end

  def verify?
    admin_or_owner?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
