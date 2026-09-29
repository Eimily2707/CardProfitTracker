class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.string :locale
      t.string :time_zone, null: false, default: "UTC"
      t.datetime :confirmed_at
      t.string :otp_secret
      t.boolean :super_admin, null: false, default: false

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
