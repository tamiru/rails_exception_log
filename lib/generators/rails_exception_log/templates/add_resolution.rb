# frozen_string_literal: true

# Lets exceptions be marked resolved, and flags them when they come back.
class AddResolutionToRailsExceptionLogExceptions < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    add_column :rails_exception_log_exceptions, :resolved_at, :datetime
    add_column :rails_exception_log_exceptions, :resolved_by, :string
    add_column :rails_exception_log_exceptions, :regressed_at, :datetime
    add_index :rails_exception_log_exceptions, :resolved_at
  end
end
