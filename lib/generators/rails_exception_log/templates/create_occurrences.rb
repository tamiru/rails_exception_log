# frozen_string_literal: true

# Records when each exception occurred, for the list's 7-day trend.
class CreateRailsExceptionLogOccurrences < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :rails_exception_log_occurrences do |t|
      t.bigint   :logged_exception_id, null: false
      t.datetime :occurred_at, null: false
    end

    add_index :rails_exception_log_occurrences, [:logged_exception_id, :occurred_at],
              name: "index_rel_occurrences_on_exception_and_time"
    add_index :rails_exception_log_occurrences, :occurred_at
  end
end
