# frozen_string_literal: true

module RailsExceptionLog
  class Engine < ::Rails::Engine
    isolate_namespace RailsExceptionLog

    engine_name "rails_exception_log"

    # ─── Asset paths (Propshaft and Sprockets) ───

    initializer "rails_exception_log.assets", before: "propshaft.assets_middleware", group: :all do |app|
      next unless app.config.respond_to?(:assets)

      # Sprockets 4 only compiles assets listed in a manifest or in the
      # precompile list. Register these here so mounting applications do not
      # need to modify their own asset manifest.
      if app.config.assets.respond_to?(:precompile)
        app.config.assets.precompile += %w[
          rails_exception_log/application.css
          rails_exception_log/application.js
        ]
      end
    end

    # ─── Database connection (separate DB support) ─────────────────

    initializer "rails_exception_log.database" do
      ActiveSupport.on_load(:active_record) do
        config = RailsExceptionLog.configuration

        if config.database_url.present?
          uri = URI.parse(config.database_url)
          RailsExceptionLog::BaseRecord.establish_connection(
            adapter: uri.scheme,
            host: uri.host,
            port: uri.port&.to_i,
            username: URI.decode_www_form_component(uri.user || ""),
            password: URI.decode_www_form_component(uri.password || ""),
            database: uri.path&.gsub(%r{^/}, "")
          )
          Rails.logger.info("[RailsExceptionLog] Connected to separate database: #{config.database_url.split("@").last}") if Rails.logger

        elsif config.database_name.present?
          yaml_path = Rails.root.join("config", "database.yml")
          if yaml_path.exist?
            yaml = YAML.safe_load(ERB.new(yaml_path.read).result, aliases: true) || {}
            env_config = yaml[Rails.env.to_s] || yaml[Rails.env]
            if env_config.is_a?(Hash)
              db_config = env_config.symbolize_keys
              db_config[:database] = config.database_name if config.database_name.is_a?(String)
              RailsExceptionLog::BaseRecord.establish_connection(**db_config)
              Rails.logger.info("[RailsExceptionLog] Connected to database: #{config.database_name}") if Rails.logger
            end
          end

        elsif config.database_yml.present?
          yaml_path = Rails.root.join(config.database_yml)
          if yaml_path.exist?
            yaml = YAML.safe_load(ERB.new(yaml_path.read).result, aliases: true) || {}
            env_config = yaml[Rails.env.to_s] || yaml[Rails.env]
            RailsExceptionLog::BaseRecord.establish_connection(**env_config.symbolize_keys) if env_config.is_a?(Hash)
            Rails.logger.info("[RailsExceptionLog] Connected to database from #{config.database_yml}") if Rails.logger
          end
        end
        # If none configured, BaseRecord inherits ApplicationRecord's connection (default)
      end
    end

    # ─── Ransack configuration ───────────────────────────────────

    initializer "rails_exception_log.ransack" do
      ActiveSupport.on_load(:active_record) do
        require "rails_exception_log/ransack_config" if defined?(Ransack)
      end
    end

    # ─── Load support modules ─────────────────────────────────────

    initializer "rails_exception_log.support" do
      require "rails_exception_log/notifications"
      require "rails_exception_log/cleanup"
      require "rails_exception_log/storm_protection"
    end

    # ─── Rake tasks ──────────────────────────────────────────────

    initializer "rails_exception_log.rake_tasks" do
      load "tasks/rails_exception_log.rake" if Rake.respond_to?(:application)
    end

    # ─── Hook into after_create for notifications ─────────────────

    initializer "rails_exception_log.after_create" do
      ActiveSupport.on_load(:active_record) do
        if defined?(RailsExceptionLog::LoggedException)
          RailsExceptionLog::LoggedException.after_create do |exception|
            RailsExceptionLog::Notifications.notify(exception)
          rescue StandardError => e
            Rails.logger.error("[RailsExceptionLog] Notification error: #{e.message}")
          end
        end
      end
    end

    # ─── Storm protection ─────────────────────────────────────────

    initializer "rails_exception_log.storm_protection" do
      ActiveSupport.on_load(:active_record) do
        require "rails_exception_log/storm_protection"
      end
    end

    # ─── Automatic capture ────────────────────────────────────────
    # Each hook checks its config.capture_* flag when an error happens, so
    # the flags can be set in the host initializer as usual.

    initializer "rails_exception_log.capture_middleware" do |app|
      app.middleware.use RailsExceptionLog::Middleware
    end

    config.after_initialize do
      Rails.error.subscribe(RailsExceptionLog::ErrorSubscriber.new) if Rails.respond_to?(:error)
      RailsExceptionLog::ActiveJobCapture.subscribe!
      RailsExceptionLog::SidekiqCapture.install!
      RailsExceptionLog::RakeCapture.install!
      at_exit { RailsExceptionLog::AsyncWriter.shutdown }
    end

    # ─── Breadcrumbs subscription ─────────────────────────────────

    initializer "rails_exception_log.breadcrumbs" do
      ActiveSupport.on_load(:active_record) do
        require "rails_exception_log/breadcrumbs"
        if RailsExceptionLog.configuration.breadcrumbs_enabled
          RailsExceptionLog::Breadcrumbs.subscribe!
        end
      end
    end
  end
end
