# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RailsExceptionLog
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Install RailsExceptionLog into your Rails application"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_files
        migration_template "migration.rb", "db/migrate/create_rails_exception_log_tables.rb"
      end

      def create_initializer
        template "rails_exception_log.rb", "config/initializers/rails_exception_log.rb"
      end

      def mount_routes
        route 'mount RailsExceptionLog::Engine, at: "/rails_exception_log"'
      end

      def add_rescue_from
        app_controller = "app/controllers/application_controller.rb"
        destination_controller = File.join(destination_root, app_controller)

        if File.exist?(destination_controller)
          content = File.read(destination_controller)
          unless content.include?("log_exception_handler")
            inject_into_class app_controller, "ApplicationController" do
              "\n  rescue_from StandardError, with: :log_exception_handler\n"
            end
          end
        end
      end

      def show_readme
        readme "INSTALL.md" if behavior == :invoke
      end
    end
  end
end
