class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :account, null: false, foreign_key: true
      t.citext :email, null: false
      t.string :role, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.references :invited_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :invitations, :token_digest, unique: true
  end
end
