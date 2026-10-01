class CreateTasks < ActiveRecord::Migration[8.1]
  # spec §4.15/§5.11 ("Da sistemare"): the app's real notification/to-do
  # system - service objects open and close these, users only snooze or
  # dismiss. account_id is denormalized (not in the spec's own table, whose
  # only account link is through the polymorphic subject) for the same
  # reason every other tenant-facing list in this app has it: a simple,
  # indexable per-account scope instead of joining through subject_type.
  def change
    create_table :tasks do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false
      t.references :subject, polymorphic: true, null: false
      t.string :priority, null: false
      t.string :status, null: false, default: "open"
      t.references :assignee, foreign_key: { to_table: :users }
      t.datetime :snoozed_until
      t.date :due_on
      t.datetime :resolved_at
      t.string :resolution
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    # spec §4.15: "unique con kind finché open" - one open task per
    # (subject, kind); a resolved/dismissed one doesn't block a fresh one.
    add_index :tasks, %i[subject_type subject_id kind], unique: true, where: "status IN ('open', 'snoozed')",
              name: "index_tasks_on_subject_and_kind_while_open"
    add_index :tasks, %i[account_id status]
  end
end
