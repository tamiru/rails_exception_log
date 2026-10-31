# frozen_string_literal: true

module RailsExceptionLog
  # Checks that RailsExceptionLog is set up correctly in the host app and says
  # how to fix anything that is not. Run with `bin/rails rails_exception_log:doctor`.
  class Doctor
    Check = Struct.new(:status, :name, :detail, :fix, keyword_init: true) do
      def ok? = status == :ok
      def failed? = status == :fail
    end

    TABLES = %w[rails_exception_log_exceptions rails_exception_log_comments rails_exception_log_webhook_deliveries].freeze
    LEGACY_TABLE = "rails_nexus_exceptions"
    ASSETS = %w[rails_exception_log/application.css rails_exception_log/application.js].freeze
    LEGACY_REFERENCE = /\bRailsNexus(::|\.)/
    REFERENCE_GLOBS = %w[app/**/*.rb app/**/*.erb config/**/*.rb lib/**/*.rb].freeze

    attr_reader :app, :checks

    def initialize(app = Rails.application)
      @app = app
      @checks = []
    end

    def run
      @checks = []
      check_database
      check_route
      check_authentication
      check_capture
      check_precompiled_assets
      check_legacy_references
      checks
    end

    def healthy?
      checks.none?(&:failed?)
    end

    # Path the engine is mounted at, e.g. "/rails_exception_log", or nil.
    def dashboard_path
      route = app.routes.routes.find { |r| mounted_engine(r) == RailsExceptionLog::Engine }
      route&.path&.spec.to_s.sub("(.:format)", "").presence
    end

    def report(io = $stdout)
      run if checks.empty?
      io.puts "RailsExceptionLog #{RailsExceptionLog::VERSION} (#{Rails.env})"
      checks.each do |check|
        io.puts "  #{SYMBOLS.fetch(check.status)} #{check.name}#{": #{check.detail}" if check.detail.present?}"
        io.puts "      fix: #{check.fix}" if check.fix.present? && !check.ok?
      end
      warnings = checks.count { |check| check.status == :warn }
      io.puts(if !healthy?
                "Fix the items marked ✗ above."
              elsif warnings.positive?
                "Working, but check the #{warnings == 1 ? "item" : "items"} marked ! above."
              else
                "Everything looks good."
              end)
      healthy?
    end

    SYMBOLS = { ok: "✓", warn: "!", fail: "✗" }.freeze

    private

    def add(status, name, detail = nil, fix: nil)
      checks << Check.new(status: status, name: name, detail: detail, fix: fix)
    end

    def check_database
      connection = RailsExceptionLog::LoggedException.connection
      missing = TABLES.reject { |table| connection.table_exists?(table) }

      if missing.empty?
        count = RailsExceptionLog::LoggedException.count
        add :ok, "Database tables", "#{count} #{count == 1 ? "exception" : "exceptions"} recorded"
      elsif connection.table_exists?(LEGACY_TABLE)
        add :fail, "Database tables", "rails_nexus tables found, rails_exception_log tables missing",
            fix: "bin/rails generate rails_exception_log:install && bin/rails db:migrate"
      else
        add :fail, "Database tables", "missing #{missing.join(", ")}",
            fix: "bin/rails generate rails_exception_log:install && bin/rails db:migrate"
      end

      if pending_migrations?
        add :warn, "Migrations", "the app has pending migrations", fix: "bin/rails db:migrate"
      end
    rescue StandardError => e
      add :fail, "Database tables", "could not connect (#{e.class}: #{e.message})",
          fix: "check config/database.yml (or config.database_url) and that the database is running"
    end

    def pending_migrations?
      pool = ActiveRecord::Base.connection_pool
      context = pool.respond_to?(:migration_context) ? pool.migration_context : ActiveRecord::Base.connection.migration_context
      context.needs_migration?
    rescue StandardError
      false
    end

    def check_route
      if (path = dashboard_path)
        add :ok, "Dashboard route", path
      else
        add :fail, "Dashboard route", "the engine is not mounted",
            fix: %(add `mount RailsExceptionLog::Engine, at: "/rails_exception_log"` to config/routes.rb)
      end
    end

    # Unwraps route constraints to the mounted app. Controller endpoints
    # return themselves from #app, so stop when unwrapping makes no progress.
    def mounted_engine(route)
      target = route.app
      5.times do
        break if target.is_a?(Class) || !target.respond_to?(:app)

        inner = target.app
        break if inner.equal?(target)

        target = inner
      end
      target
    rescue StandardError
      nil
    end

    def check_authentication
      if RailsExceptionLog.configuration.auth_block
        add :ok, "Dashboard access", "auth_block configured"
      else
        add :warn, "Dashboard access", "no auth_block, so the dashboard denies every request",
            fix: "set config.auth_block in config/initializers/rails_exception_log.rb"
      end
    end

    def check_capture
      config = RailsExceptionLog.configuration
      unless config.capture_enabled
        add :warn, "Capture", "config.capture_enabled is false, nothing is recorded"
        return
      end

      sources = []
      sources << "requests" if config.capture_requests && app.middleware.include?(RailsExceptionLog::Middleware)
      sources << "ActiveJob" if config.capture_jobs
      sources << "Sidekiq" if config.capture_sidekiq && defined?(::Sidekiq)
      sources << "rake" if config.capture_rake_tasks
      sources << "Rails.error" if config.capture_rails_errors && rails_error_subscribed?
      mode = config.async_capture? ? "background writes" : "synchronous writes"
      add :ok, "Capture", "#{sources.join(", ")} (#{mode})"

      if config.capture_requests && !app.middleware.include?(RailsExceptionLog::Middleware)
        add :fail, "Request capture", "RailsExceptionLog::Middleware is not in the middleware stack",
            fix: "make sure the gem is loaded before the app boots (it is listed in the Gemfile, not required later)"
      end
    end

    def rails_error_subscribed?
      subscribers = Rails.error.instance_variable_get(:@subscribers)
      subscribers.nil? || subscribers.any? { |subscriber| subscriber.is_a?(RailsExceptionLog::ErrorSubscriber) }
    rescue StandardError
      true
    end

    # A public/assets manifest built before the gem was installed or updated
    # makes Propshaft/Sprockets serve only what it lists, so the dashboard
    # fails with "asset not found".
    def check_precompiled_assets
      manifest = Dir.glob(Rails.root.join("public/assets/{.manifest.json,.sprockets-manifest-*.json,manifest-*.json}")).first
      return unless manifest

      contents = File.read(manifest)
      missing = ASSETS.reject { |asset| contents.include?(asset) }
      if missing.empty?
        add :ok, "Precompiled assets", "dashboard assets present"
      else
        add :fail, "Precompiled assets", "#{File.basename(manifest)} was built without #{missing.join(", ")}",
            fix: "bin/rails assets:precompile (in development you can delete public/assets instead)"
      end
    rescue StandardError => e
      add :warn, "Precompiled assets", "could not read manifest (#{e.class})"
    end

    def check_legacy_references
      files = REFERENCE_GLOBS.flat_map { |glob| Dir.glob(Rails.root.join(glob)) }.uniq.select do |path|
        File.read(path).match?(LEGACY_REFERENCE)
      rescue StandardError
        false
      end
      return if files.empty?

      relative = files.map { |path| path.delete_prefix("#{Rails.root}/") }.sort
      add :fail, "Old rails_nexus references", relative.first(5).join(", ") + (relative.size > 5 ? ", ..." : ""),
          fix: "bin/rails generate rails_exception_log:install (updates them for you)"
    end
  end
end
