class AddObjectChangesToVersions < ActiveRecord::Migration[8.1]
  # PaperTrail's standard install migration includes this column - without
  # it, Version#changeset (used by the audit log UI, spec §2.4) has no
  # per-field before/after diff to report. Never wired up since the
  # versions table was first created in Tranche 1.
  def change
    add_column :versions, :object_changes, :text
  end
end
