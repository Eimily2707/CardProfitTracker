class CtBlueprint < ApplicationRecord
  belongs_to :ct_game, foreign_key: :ct_game_id, primary_key: :ct_id, inverse_of: :ct_blueprints
  belongs_to :ct_category, foreign_key: :ct_category_id, primary_key: :ct_id, inverse_of: :ct_blueprints
  belongs_to :ct_expansion, foreign_key: :ct_expansion_id, primary_key: :ct_id, optional: true, inverse_of: :ct_blueprints

  validates :ct_id, presence: true, uniqueness: true
  validates :name, presence: true

  before_save :compute_search_text, if: -> { name_changed? || version_changed? || search_text.nil? }

  scope :active, -> { where(removed_at: nil) }
  scope :in_expansion, ->(ct_expansion_id) { ct_expansion_id.present? ? where(ct_expansion_id: ct_expansion_id) : all }
  scope :in_category, ->(ct_category_id) { ct_category_id.present? ? where(ct_category_id: ct_category_id) : all }
  scope :in_game, ->(ct_game_id) { ct_game_id.present? ? where(ct_game_id: ct_game_id) : all }

  # US-1.2 (§6.1): exact match, then prefix, then trigram similarity; % and _
  # in the query are treated literally, never as SQL LIKE wildcards.
  def self.search(query, limit: 15)
    normalized = normalize_for_search(query)
    return none if normalized.blank? || normalized.length < 2

    like_pattern = "%#{sanitize_sql_like(normalized)}%"
    prefix_pattern = "#{sanitize_sql_like(normalized)}%"
    quoted_normalized = connection.quote(normalized)
    quoted_prefix = connection.quote(prefix_pattern)

    # word_similarity/<% (not similarity/%): search_text concatenates name,
    # version and expansion name/code, so a short query's *whole-string*
    # similarity against that longer text is diluted well below the
    # default threshold. word_similarity compares the query against the
    # best-matching substring instead, which is what a typo-tolerant
    # search over a multi-word field needs.
    active
      .where("search_text LIKE :like OR :trgm <% search_text", like: like_pattern, trgm: normalized)
      .order(Arel.sql(<<~SQL.squish))
        CASE
          WHEN search_text = #{quoted_normalized} THEN 0
          WHEN search_text LIKE #{quoted_prefix} THEN 1
          ELSE 2
        END,
        word_similarity(#{quoted_normalized}, search_text) DESC
      SQL
      .limit(limit)
  end

  # Collector numbers are catalog language, so this is an exact match, not
  # fuzzy - the independent-of-language alternative the spec calls for
  # ("Blue-Eyes White Dragon" vs "Drago Bianco").
  def self.search_by_collector_number(number, ct_expansion_id: nil)
    return none if number.blank?

    active.in_expansion(ct_expansion_id).where(collector_number: number).limit(15)
  end

  # lower(unaccent(name + version + nome espansione + codice espansione)) -
  # computed here (not a stored generated column) because unaccent isn't
  # IMMUTABLE (§4.3). Recompute_search_text! below does the same in bulk
  # for the sync job's batched upserts.
  def self.normalize_for_search(text)
    return nil if text.blank?

    connection.select_value("SELECT lower(unaccent(#{connection.quote(text.to_s.strip)}))").presence
  end

  # Bulk-recomputes search_text for exactly the given ct_ids in one or two
  # statements, instead of one round trip per row - used after each
  # upsert_all batch in Cardtrader::CatalogSync.
  def self.recompute_search_text!(ct_ids)
    return if ct_ids.blank?

    ids = ct_ids.map(&:to_i)

    connection.execute(sanitize_sql_array([ <<~SQL.squish, ids ]))
      UPDATE ct_blueprints
      SET search_text = lower(unaccent(concat_ws(' ',
        ct_blueprints.name, ct_blueprints.version, ct_expansions.name, ct_expansions.code
      )))
      FROM ct_expansions
      WHERE ct_blueprints.ct_expansion_id = ct_expansions.ct_id
        AND ct_blueprints.ct_id IN (?)
    SQL

    connection.execute(sanitize_sql_array([ <<~SQL.squish, ids ]))
      UPDATE ct_blueprints
      SET search_text = lower(unaccent(concat_ws(' ', name, version)))
      WHERE ct_expansion_id IS NULL
        AND ct_id IN (?)
    SQL
  end

  private

  def compute_search_text
    parts = [ name, version, ct_expansion&.name, ct_expansion&.code ].compact_blank.join(" ")
    self.search_text = self.class.normalize_for_search(parts)
  end
end
