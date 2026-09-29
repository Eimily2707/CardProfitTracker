class EnablePostgresExtensions < ActiveRecord::Migration[8.1]
  def change
    # Trigram similarity search (catalog/blueprint search, §4.3, §6.1)
    enable_extension "pg_trgm"
    # Accent-insensitive search/comparison alongside pg_trgm
    enable_extension "unaccent"
    # Case-insensitive text columns (users.email, invitations.email, §4.2)
    enable_extension "citext"
  end
end
