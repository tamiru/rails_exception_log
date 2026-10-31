# Changelog

All notable changes to RailsExceptionLog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-10-31

### Added
- **Automatic capture everywhere** — Exceptions are recorded without any
  controller or job changes:
  - Rack middleware for every request, including engine and API controllers
    that never include `ExceptionLoggable`.
  - ActiveJob failures (final failures only; attempts that `retry_on` will
    retry are skipped), with job class, ID, queue, attempts, and arguments.
  - A Sidekiq error handler for plain Sidekiq jobs, registered automatically.
  - Rake tasks that load the app.
  - A `Rails.error` subscriber, covering `rails runner` and
    `Rails.error.record`/`report`.
- **Background writes** — Records are written on a background thread with a
  bounded queue (`async_queue_size`), restarted after fork and drained at exit.
  Synchronous in the test environment.
- **`RailsExceptionLog.capture(exception, data: {})`** for exceptions you rescue
  yourself.
- Settings: `capture_enabled`, `capture_requests`, `capture_jobs`,
  `capture_sidekiq`, `capture_rake_tasks`, `capture_rails_errors`,
  `capture_handled_errors`, `ignored_exceptions`, `async_capture`,
  `async_queue_size`.

### Changed
- An exception seen by several hooks (for example the controller concern and
  the middleware) is recorded once.
- 404s and malformed requests (`ActiveRecord::RecordNotFound`,
  `ActionController::RoutingError`, `ActionController::BadRequest`, and similar)
  are skipped by default; edit `ignored_exceptions` to record them.
- Webhook and Telegram notifications are sent from the background writer
  instead of the failing request.
- Development dependencies updated to Rails 8.1.4.

## [2.0.0] - 2026-10-31

A rewrite based on the exception-logging core of `rails_nexus` 2.1.5. This is
not a drop-in upgrade from 1.x.

### Upgrading from 1.x
- Exceptions are stored in new tables (`rails_exception_log_exceptions`,
  `rails_exception_log_comments`, `rails_exception_log_webhook_deliveries`).
  Run `bin/rails generate rails_exception_log:install` and `bin/rails db:migrate`.
  The 1.x table `rails_exception_log_logged_exceptions` is not migrated; drop it
  once you no longer need the old records.
- Include `RailsExceptionLog::ExceptionLoggable` and use
  `rescue_from StandardError, with: :log_exception_handler` (the installer adds this).
- Configure the gem in `config/initializers/rails_exception_log.rb`; dashboard
  access is denied unless `config.auth_block` returns true.
- Requires Ruby 3.2+ and Rails 8.0+.

### Added
- Exception dashboard with search, filters, keyboard shortcuts, dark/light theme, and RSS feed.
- Cause chains, breadcrumbs, user impact ranking, platform detection, and storm protection.
- Workflow (assign, priority, snooze, mute) and comments.
- Inline source code viewer with git blame.
- Webhook and Telegram notifications, Sidekiq middleware, and webhook delivery logging.
- Structured JSON logging, retention cleanup, and export/tail rake tasks.
