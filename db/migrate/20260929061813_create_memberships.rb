class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    add_index :memberships, %i[account_id user_id], unique: true

    # "Esattamente un owner per account" (§4.2): this enforces the "at most
    # one" half at the database level; Membership itself enforces "at least
    # one" by refusing to destroy/demote an account's last owner.
    add_index :memberships, :account_id, unique: true, where: "role = 'owner'", name: "index_memberships_on_account_id_when_owner"
  end
end
