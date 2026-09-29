module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
    validates :account, presence: true

    scope :for_account, ->(account) { where(account: account) }
  end
end
