class CtExpansion < ApplicationRecord
  EXPORT_STATUSES = %w[ok pending_export].freeze

  belongs_to :ct_game, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_expansions
  has_many :ct_blueprints, foreign_key: :ct_expansion_id, primary_key: :ct_id, inverse_of: :ct_expansion

  validates :ct_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :export_status, inclusion: { in: EXPORT_STATUSES }

  scope :active, -> { where(removed_at: nil) }
end
