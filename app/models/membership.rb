class Membership < ApplicationRecord
  include TenantScoped

  ROLES = %w[owner admin operator viewer].freeze

  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :account_id }
  validate :only_one_owner_per_account

  # "Esattamente un owner per account" (§4.2) means the owner role can't be
  # changed or removed through the normal update/destroy path at all - since
  # only_one_owner_per_account (and a matching partial unique index) never
  # let a second owner membership exist, there's never "another owner" to
  # fall back on. Transferring ownership needs a dedicated operation that
  # swaps both memberships' roles atomically, bypassing this guard - not
  # implemented yet.
  validate :owner_role_is_immutable, on: :update, if: -> { role_changed? && role_was == "owner" }

  before_destroy :prevent_destroying_the_owner

  ROLES.each do |defined_role|
    define_method("#{defined_role}?") { role == defined_role }
  end

  def role_label
    I18n.t(role, scope: "enums.membership.role")
  end

  private

  def only_one_owner_per_account
    return unless role == "owner"

    existing = Membership.where(account_id: account_id, role: "owner").where.not(id: id)
    errors.add(:role, :owner_already_exists) if existing.exists?
  end

  def owner_role_is_immutable
    errors.add(:role, :cannot_demote_last_owner)
  end

  def prevent_destroying_the_owner
    throw :abort if role == "owner"
  end
end
