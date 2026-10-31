# frozen_string_literal: true

module RailsExceptionLog
  # Abstract base class for all RailsExceptionLog models.
  # Supports connecting to a separate database via configuration.
  #
  # When NO database config is set, this behaves identically to ApplicationRecord.
  # The host app's default connection is used for all queries.
  #
  # Config options:
  #   config.database_url = "mysql2://user:pass@localhost/rails_exception_log"
  #   config.database_name = "rails_exception_log"   # looks up in config/database.yml
  #   config.database_yml = "config/rails_exception_log_database.yml"
  #
  class BaseRecord < ApplicationRecord
    self.abstract_class = true

    class << self
      # Check if a separate database is configured
      def separate_database?
        config = RailsExceptionLog.configuration
        config.database_url.present? || config.database_name.present? || config.database_yml.present?
      end
    end
  end
end
