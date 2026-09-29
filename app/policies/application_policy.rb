# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  # The account this record belongs to - the record itself for Account, and
  # Current.account when record is a bare class (authorize SomeModel, :index?
  # for a collection action, or :create? on a not-yet-saved, account-less
  # record) rather than a persisted instance.
  def account
    return record if record.is_a?(Account)
    return Current.account if record.is_a?(Class)

    record.try(:account) || Current.account
  end

  def membership
    return nil unless user && account

    @membership ||= user.memberships.find_by(account: account)
  end

  def owner?
    membership&.role == "owner"
  end

  def admin?
    membership&.role == "admin"
  end

  def operator?
    membership&.role == "operator"
  end

  def viewer?
    membership&.role == "viewer"
  end

  def admin_or_owner?
    owner? || admin?
  end
end
