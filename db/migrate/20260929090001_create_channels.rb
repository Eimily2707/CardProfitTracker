class CreateChannels < ActiveRecord::Migration[8.1]
  # Purchase and sale "channel" (spec §4.7): who/where a purchase came from
  # or a sale went to. Tenant-scoped, with a set of preloaded system_key
  # rows seeded per account (Channel.seed_defaults_for!, called from
  # Account#after_create).
  def change
    create_table :channels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :kind, null: false
      t.string :system_key
      t.string :usage, null: false, default: "both"
      t.string :credit_timing, null: false, default: "manual"
      t.string :default_currency, limit: 3
      t.boolean :allows_bundles, null: false, default: true
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :channels, %i[account_id name], unique: true
    add_index :channels, %i[account_id system_key], unique: true
  end
end
