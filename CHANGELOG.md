# Changelog

All notable changes to RailsExceptionLog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
