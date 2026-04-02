# rails_exception_log - Specification

## 1. Project Overview

- **Project name**: rails_exception_log
- **Type**: Rails Engine Gem
- **Core functionality**: A modern exception logging gem that stores Rails exceptions in a database table with a beautiful Tailwind UI dashboard
- **Target users**: Rails 7 and 8 developers who need to track and monitor application exceptions

## 2. Technology Stack

- **Ruby**: >= 3.0
- **Rails**: >= 7.0, < 9.0 (Rails 7 and 8 support)
- **Package Manager**: Bun
- **CSS Framework**: Tailwind CSS (via css-bundling-rails)
- **Database**: ActiveRecord (SQLite, PostgreSQL, MySQL compatible)

### Gem Dependencies
- `rails` >= 7.0
- `css-bundling-rails` >= 1.4
- `tailwindcss-rails` >= 3.0
- `bun` (runtime for CSS bundling)

## 3. Feature List

### Core Features
1. **Exception Logging**: Automatically log all exceptions to database
2. **Dashboard UI**: Modern Tailwind-styled dashboard to view exceptions
3. **Exception Details**: Show full stack trace, request params, session data
4. **Filtering**: Filter exceptions by date range, type, controller/action
5. **Pagination**: Paginate exception list
6. **Search**: Search exceptions by message or class name
7. **Exception Cleanup**: Delete old exceptions manually or via rake task
8. **Authentication Hook**: Allow custom authentication integration

### Advanced Features (Honeybadger-style)
1. **Error Grouping**: Group similar exceptions together using fingerprint
2. **Error Status**: Track error status (open, resolved, reopened, ignored)
3. **Occurrence Count**: Count occurrences per error group
4. **User Tracking**: Track which user was affected by the error
5. **Fingerprint Deduplication**: Prevent duplicate error logging (configurable)
6. **Error Comments**: Add comments to errors for team collaboration
7. **Mark as Resolved**: Manually mark errors as resolved
8. **Reopen on Recurrence**: Auto-reopen if same error occurs after resolution
9. **Rate Limiting**: Configurable rate limiting to prevent database flooding
10. **Deploy Tracking**: Track which deploy fixed/introduced errors
11. **Error Context**: Custom additional context/data per error
12. **Email Notifications**: Optional email alerts for new errors
13. **i18n Support**: Internationalization ready

### Technical Features
1. **Mountable Engine**: Easy to mount in any Rails app
2. **Migrations**: Rails generator to copy migrations
3. **Bun Integration**: Use Bun for Tailwind CSS building
4. **CSS Bundling**: Use css-bundling-rails for asset pipeline
5. **Rails 8 Ready**: Compatible with both Rails 7 and 8

## 4. UI/UX Specification

### Color Palette
- **Primary**: Indigo-600 (#4F46E5)
- **Secondary**: Slate-500 (#64748B)
- **Background**: Slate-50 (#F8FAFC)
- **Card Background**: White (#FFFFFF)
- **Error/Exception**: Red-600 (#DC2626)
- **Warning**: Amber-500 (#F59E0B)
- **Success**: Green-600 (#16A34A)

### Typography
- **Font**: Inter (via Tailwind default)
- **Headings**: Bold, various sizes
- **Body**: Regular, 14-16px
- **Code**: Monospace for stack traces

### Layout
- **Navigation**: Top navbar with gem branding
- **Sidebar**: Filter options (date range, exception type)
- **Main Content**: Exception list/table
- **Responsive**: Mobile-friendly

### Components
- **Exception Table**: Sortable, with status badges
- **Detail Modal/Page**: Full exception details with tabs
- **Filter Panel**: Date picker, dropdowns
- **Action Buttons**: Delete, export, refresh

## 5. Database Schema

### Table: logged_exceptions
| Column | Type | Description |
|--------|------|-------------|
| id | bigint | Primary key |
| exception_class | string | Exception class name |
| message | text | Exception message |
| backtrace | text | Full stack trace |
| controller_name | string | Controller where error occurred |
| action_name | string | Action where error occurred |
| request_method | string | HTTP method |
| request_path | string | Request path |
| request_params | json | Request parameters |
| request_headers | json | Request headers |
| session_data | json | Session data |
| environment | string | Rails environment |
| created_at | datetime | When exception occurred |
| updated_at | datetime | Last update |

## 6. Installation & Usage

### Gemfile
```ruby
gem "rails_exception_log"
```

### Routes
```ruby
# config/routes.rb
mount RailsExceptionLog::Engine => "/exceptions"
```

### ApplicationController
```ruby
class ApplicationController < ActionController::Base
  include RailsExceptionLog::ExceptionLoggable
  rescue_from Exception, with: :log_exception_handler
end
```

### Install Migrations
```bash
rails rails_exception_log:install:migrations
rails db:migrate
```

### Authentication (Optional)
```ruby
config.after_initialize do
  RailsExceptionLog::LoggedExceptionsController.class_eval do
    before_action :authenticate_admin!
  end
end
```

## 7. File Structure

```
rails_exception_log/
├── app/
│   ├── assets/
│   │   ├── builds/
│   │   │   └── .keep
│   │   ├── config/
│   │   │   └── tailwind.config.js
│   │   └── stylesheets/
│   │       └── rails_exception_log/
│   │           └── application.css
│   ├── controllers/
│   │   └── rails_exception_log/
│   │       ├── concerns/
│   │       │   └── .keep
│   │       ├── application_controller.rb
│   │       └── logged_exceptions_controller.rb
│   ├── helpers/
│   │   └── rails_exception_log/
│   │       └── application_helper.rb
│   ├── models/
│   │   └── rails_exception_log/
│   │       └── logged_exception.rb
│   └── views/
│       └── rails_exception_log/
│           └── logged_exceptions/
│               ├── _exception.html.erb
│               ├── _filters.html.erb
│               ├── index.html.erb
│               └── show.html.erb
├── config/
│   └── routes.rb
├── db/
│   └── migrate/
│       └── 20240101000000_create_rails_exception_log_logged_exceptions.rb
├── lib/
│   ├── generators/
│   │   └── rails_exception_log/
│   │       └── install/
│   │           └── install_generator.rb
│   ├── rails_exception_log.rb
│   └── rails_exception_log/
│       ├── engine.rb
│       └── version.rb
├── Gemfile
├── Rakefile
└── rails_exception_log.gemspec
```

## 8. Acceptance Criteria

1. Gem installs cleanly in Rails 7 and 8 apps
2. Exceptions are automatically logged to database
3. Dashboard displays exceptions with Tailwind styling
4. Filtering by date and exception type works
5. Exception details show full stack trace and request data
6. Migrations can be copied to host app
7. Bun is used for Tailwind CSS bundling
8. Authentication can be customized
9. All text is internationalizable
10. Tests pass for core functionality