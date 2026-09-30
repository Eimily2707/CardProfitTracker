# frozen_string_literal: true

module Cardtrader
  class OrderSyncRunPolicy < ApplicationPolicy
    def index?
      membership.present?
    end

    def show?
      membership.present?
    end

    def create?
      operator_or_above?
    end

    class Scope < Scope
      def resolve
        return scope.none unless user

        scope.where(account: user.accounts)
      end
    end
  end
end
