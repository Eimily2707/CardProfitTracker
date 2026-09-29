class CtCategory < ApplicationRecord
  belongs_to :ct_game, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_categories
  has_many :ct_blueprints, foreign_key: :ct_category_id, primary_key: :ct_id, inverse_of: :ct_category

  validates :ct_id, presence: true, uniqueness: true
  validates :name, presence: true
end
