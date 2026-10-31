# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RailsExceptionLog
  module Generators
    # Installs RailsExceptionLog, and is safe to run again after every gem
    # update: each step skips work that is already done. Projects that used
    # rails_nexus are converted (tables renamed with their data, initializer,
    # route, and code references updated).
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Install or update RailsExceptionLog (safe to run again after every update)"

      INITIALIZER = "config/initializers/rails_exception_log.rb"
      LEGACY_INITIALIZER = "config/initializers/rails_nexus.rb"
      CREATE_MIGRATION = "create_rails_exception_log_tables"
      RENAME_MIGRATION = "rename_rails_nexus_tables_to_rails_exception_log"
      LEGACY_MIGRATION = "create_rails_nexus_tables"
      MOUNT = 'mount RailsExceptionLog::Engine, at: "/rails_exception_log"'
      LEGACY_MOUNT = /^(\s*)mount\s+RailsNexus::Engine\b.*$/
      # Code references updated when converting from rails_nexus.
      LEGACY_REFERENCES = {
        "RailsNexus::" => "RailsExceptionLog::",
        "RailsNexus." => "RailsExceptionLog.",
        "'/rails_nexus'" => "'/rails_exception_log'",
        "\"/rails_nexus\"" => "\"/rails_exception_log\""
      }.freeze
      REFERENCE_GLOBS = %w[app/**/*.rb app/**/*.erb config/**/*.rb lib/**/*.rb].freeze

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_files
        if migration_exists?(CREATE_MIGRATION) || migration_exists?(RENAME_MIGRATION)
          say_status :skip, "database migration already present", :yellow
        elsif migration_exists?(LEGACY_MIGRATION)
          migration_template "rename_rails_nexus_tables.rb", "db/migrate/#{RENAME_MIGRATION}.rb"
        else
          migration_template "migration.rb", "db/migrate/#{CREATE_MIGRATION}.rb"
        end
      end

      def create_initializer
        if exists?(INITIALIZER)
          say_status :skip, INITIALIZER, :yellow
        elsif exists?(LEGACY_INITIALIZER)
          create_file INITIALIZER, convert_legacy(read(LEGACY_INITIALIZER))
          remove_file LEGACY_INITIALIZER
        else
          template "rails_exception_log.rb", INITIALIZER
        end
      end

      def mount_routes
        routes = read("config/routes.rb").to_s
        if routes.include?("RailsExceptionLog::Engine")
          say_status :skip, "route already mounted", :yellow
        elsif routes.match?(LEGACY_MOUNT)
          gsub_file "config/routes.rb", LEGACY_MOUNT, "\\1#{MOUNT}"
        else
          route MOUNT
        end
      end

      def update_legacy_references
        REFERENCE_GLOBS.flat_map { |glob| Dir.glob(File.join(destination_root, glob)) }.uniq.sort.each do |path|
          content = File.read(path)
          next unless LEGACY_REFERENCES.keys.any? { |old| content.include?(old) }

          relative = path.delete_prefix("#{destination_root}/")
          LEGACY_REFERENCES.each { |old, new| gsub_file(relative, old, new) if content.include?(old) }
        end
      end

      def remove_legacy_gem
        gemfile = read("Gemfile")
        return unless gemfile&.match?(/^\s*gem\s+["']rails_nexus["']/)

        if gemfile.match?(/^\s*gem\s+["']backup_nexus["']/)
          say_status :keep, "gem 'rails_nexus' (backup_nexus depends on it)", :yellow
        else
          gsub_file "Gemfile", /^\s*gem\s+["']rails_nexus["'].*\n/, ""
          @gemfile_changed = true
        end
      end

      def show_readme
        return unless behavior == :invoke

        readme "INSTALL.md"
        say "\nGemfile changed: run `bundle install`.", :yellow if @gemfile_changed
      end

      private

      def migration_exists?(name)
        Dir.glob(File.join(destination_root, "db/migrate/*_#{name}.rb")).any?
      end

      def exists?(path)
        File.exist?(File.join(destination_root, path))
      end

      def read(path)
        full_path = File.join(destination_root, path)
        File.read(full_path) if File.exist?(full_path)
      end

      def convert_legacy(content)
        LEGACY_REFERENCES.reduce(content) { |text, (old, new)| text.gsub(old, new) }
                         .gsub("rails_nexus", "rails_exception_log")
      end
    end
  end
end
