# frozen_string_literal: true

# Adds resolve/reopen tracking. A resolved exception that happens again is
# reopened and flagged as a regression.
class AddResolutionToRailsExceptionLog < ActiveRecord::Migration<%= "[#{ActiveRecord::Migration.current_version}]" %>
  TABLE = :rails_exception_log_exceptions

  def up
    add_column TABLE, :resolved_at, :datetime unless column_exists?(TABLE, :resolved_at)
    add_column TABLE, :resolved_by, :string unless column_exists?(TABLE, :resolved_by)
    add_column TABLE, :regressed_at, :datetime unless column_exists?(TABLE, :regressed_at)
    add_index TABLE, :resolved_at unless index_exists?(TABLE, :resolved_at)
  end

  def down
    remove_index TABLE, :resolved_at if index_exists?(TABLE, :resolved_at)
    remove_column TABLE, :regressed_at if column_exists?(TABLE, :regressed_at)
    remove_column TABLE, :resolved_by if column_exists?(TABLE, :resolved_by)
    remove_column TABLE, :resolved_at if column_exists?(TABLE, :resolved_at)
  end
end
