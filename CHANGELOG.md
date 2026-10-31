# Changelog

All notable changes to RailsExceptionLog will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.3.0] - 2026-10-31

### Changed
- **Detail page header** — The exception class is the title, followed by the
  occurrence count, priority, assignee, and muted/snoozed badges, the message,
  and a meta line with source, file:line, time, and IP. On phones the copy and
  close buttons move to their own row so the title gets the full width.
- **Clean messages** — The list, header, and copy button show the exception's
  own message; the appended "Extra Data" dump stays in the Context tab.
- **Exception list** — Full class names wrap at `::` instead of being cut off,
  and each row shows its priority, assignee, and muted/snoozed badges.
- **Source snippets** — Monospace font, with the failing line tinted and its
  line number highlighted.
- **Request and Environment** — Shown as key/value tables instead of
  `* Key: value` paragraphs.
- **Details grid** — Duplicate entries removed, "Source" label, two columns on
  phones, and values no longer split mid-word.

### Fixed
- Dark mode flashed light, then faded to dark, on every page load; the theme
  is now applied before the first paint.
- Previous/next navigation on the detail page pointed at the current
  exception (the record id was applied as a search filter). It now follows the
  list order and names the neighbouring exceptions.
- `rails_exception_log:customize` failed while copying the layout; it is now
  copied as-is.
- The failing source line was not highlighted (its background variable was
  never defined).

## [2.2.0] - 2026-10-31

### Added
- **Where it happened** — Each exception shows the file, line, and method in
  the application's own code: at the top of the detail page (with the
  surrounding source and git blame) and under each row in the list. When a
  core method such as `Hash#fetch` raised, the calling app method is named.
- **`bin/rails rails_exception_log:doctor`** — Checks the database tables,
  route, dashboard access, capture hooks, precompiled assets, and leftover
  rails_nexus references, and prints the fix for each problem. Exits non-zero
  on failure so it can run in deploy scripts.
- **`bin/rails rails_exception_log:test`** — Records a sample exception and
  prints its dashboard URL.
- **One command to install, update, or convert** — The install generator is
  safe to re-run: it skips the migration, initializer, and route when present.
  In a rails_nexus project it generates a table-rename migration (keeping all
  data), converts the initializer and route, updates `RailsNexus` references
  and `/rails_nexus` links, and removes the old gem from the Gemfile.

### Fixed
- Backtraces were never recognized as application code, so frames were not
  highlighted and no inline source was shown: stored paths use a
  `[RAILS_ROOT]` placeholder the view did not understand, and Ruby 3.4+
  backtrace lines (`in 'Klass#method'`) did not parse at all.
- Fresh installs could not migrate: the generated migration declared
  `ActiveRecord::Migration[[8.1]]`.
- `bin/rails generate rails_exception_log:install` crashed in apps that had not
  loaded Rake (`uninitialized constant Rake`), and rake tasks were loaded twice
  where Rake was loaded.
- The install generator added `rescue_from ... :log_exception_handler` without
  the module that defines it; it no longer edits controllers.
- `rails_exception_log:customize` copied outdated views; it now copies the
  engine's current views.
- Non-application backtrace frames showed the line number twice.

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
