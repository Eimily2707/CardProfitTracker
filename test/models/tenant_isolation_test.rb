require "test_helper"

# Spec §2.1: "Un test automatico DEVE fallire se un modello tenant non è
# coperto da scope e policy." This scans every ActiveRecord model for an
# account_id column - the signal that it's meant to be tenant-scoped -
# rather than hardcoding a model list, so a future model that adds
# account_id but forgets TenantScoped or its Pundit policy fails this test
# automatically instead of silently shipping unscoped.
class TenantIsolationTest < ActiveSupport::TestCase
  def tenant_models
    Rails.application.eager_load!
    ApplicationRecord.descendants.select { |model| model.table_exists? && model.column_names.include?("account_id") }
  end

  test "at least one tenant model exists (this test would be vacuous otherwise)" do
    assert tenant_models.any?
  end

  test "every model with an account_id column belongs_to :account with a NOT NULL column" do
    tenant_models.each do |model|
      assert model.reflect_on_association(:account),
             "#{model.name} has an account_id column but no belongs_to :account association"

      column = model.columns_hash["account_id"]
      assert_not column.null, "#{model.name}.account_id must be NOT NULL"
    end
  end

  test "every tenant model has a Pundit policy with a Scope" do
    tenant_models.each do |model|
      policy_class = "#{model.name}Policy".safe_constantize
      assert policy_class, "#{model.name} must have a #{model.name}Policy for tenant isolation"

      assert policy_class.const_defined?(:Scope, false),
             "#{policy_class} must define its own Scope to filter #{model.name} by account"
    end
  end

  test "each tenant model's Pundit Scope only resolves records within the user's own accounts" do
    tenant_models.each do |model|
      policy_class = "#{model.name}Policy".safe_constantize
      scope_class = policy_class.const_get(:Scope)

      resolved_for_elena = scope_class.new(users(:elena), model).resolve
      resolved_for_marco = scope_class.new(users(:marco), model).resolve

      cross_tenant_leak = resolved_for_elena.where(account_id: accounts(:globex).id)
      assert_empty cross_tenant_leak, "#{policy_class}::Scope leaked #{model.name} records from another account"

      cross_tenant_leak = resolved_for_marco.where(account_id: accounts(:acme).id)
      assert_empty cross_tenant_leak, "#{policy_class}::Scope leaked #{model.name} records from another account"
    end
  end

  test "each tenant model's Pundit Scope resolves nothing for a user with no memberships" do
    tenant_models.each do |model|
      policy_class = "#{model.name}Policy".safe_constantize
      scope_class = policy_class.const_get(:Scope)

      assert_empty scope_class.new(users(:guest), model).resolve
      assert_empty scope_class.new(nil, model).resolve
    end
  end
end
