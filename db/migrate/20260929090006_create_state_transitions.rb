class CreateStateTransitions < ActiveRecord::Migration[8.1]
  # spec §2.4/§4.10: append-only audit trail for every status change on an
  # entity with a lifecycle. Only Purchase writes to it this tranche; other
  # models (InventoryItem, and later SaleOrder, ...) can join in without a
  # schema change since record is polymorphic.
  def change
    create_table :state_transitions do |t|
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :from_state
      t.string :to_state, null: false
      t.string :event, null: false
      t.string :source, null: false, default: "user"
      t.references :actor_user, foreign_key: { to_table: :users }
      t.text :reason
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :state_transitions, %i[record_type record_id occurred_at]
  end
end
