class CardtraderBlueprint < ApplicationRecord
  validates :cardtrader_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :search, ->(query) { where("name LIKE ?", "%#{sanitize_sql_like(query)}%") }
end
