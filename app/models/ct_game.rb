class CtGame < ApplicationRecord
  has_many :ct_categories, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_game
  has_many :ct_expansions, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_game
  has_many :ct_blueprints, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_game

  validates :ct_id, presence: true, uniqueness: true
  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }
end
