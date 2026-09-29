# frozen_string_literal: true

class AccountPolicy < ApplicationPolicy
  def show?
    membership.present?
  end

  def update?
    admin_or_owner?
  end

  # Valuta base, fuso orario account, identificazione delle copie: owner only (§2.1)
  def update_base_currency?
    owner?
  end

  def update_time_zone?
    owner?
  end

  def update_item_identification?
    owner?
  end

  def manage_members?
    admin_or_owner?
  end

  def connect_cardtrader?
    admin_or_owner?
  end

  def export_data?
    owner?
  end

  def destroy?
    owner?
  end

  class Scope < Scope
    def resolve
      return scope.none unless user

      scope.where(id: user.accounts.select(:id))
    end
  end
end
