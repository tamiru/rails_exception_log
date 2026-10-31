# frozen_string_literal: true

# Moves exception data from rails_nexus to rails_exception_log, which uses the
# same columns under a new table prefix. The rails_nexus cron job table and any
# backup tables are left in place; drop them separately if no longer needed.
class RenameRailsNexusTablesToRailsExceptionLog < ActiveRecord::Migration<%= "[#{ActiveRecord::Migration.current_version}]" %>
  TABLES = {
    rails_nexus_exceptions: :rails_exception_log_exceptions,
    rails_nexus_comments: :rails_exception_log_comments,
    rails_nexus_webhook_deliveries: :rails_exception_log_webhook_deliveries
  }.freeze

  def up
    TABLES.each do |old_name, new_name|
      rename_table old_name, new_name if table_exists?(old_name) && !table_exists?(new_name)
    end
  end

  def down
    TABLES.each do |old_name, new_name|
      rename_table new_name, old_name if table_exists?(new_name) && !table_exists?(old_name)
    end
  end
end
