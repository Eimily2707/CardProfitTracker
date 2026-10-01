# frozen_string_literal: true

# Browsing is read-only for every role (spec §2.1 "Consultare inventario e
# report"); opening a sealed/bulk_lot item is a financial action (US-3.1),
# restricted like any other transition (operator-or-above).
class InventoryItemPolicy < ApplicationPolicy
  def index?
    membership.present?
  end

  def show?
    membership.present?
  end

  def open?
    operator_or_above?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(account: user.accounts)
    end
  end
end
