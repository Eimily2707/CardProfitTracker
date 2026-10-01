# frozen_string_literal: true

# Read-only this tranche - WriteOffs are only ever created as a side effect
# of CostPools::CloseService (spec §2.1 "Consultare inventario e report":
# every role, including viewer, may look).
class WriteOffPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
