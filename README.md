# Rails Exception Log

A modern exception logging gem for Rails 7 and 8 with Tailwind UI, inspired by Honeybadger.

## Features

- **Error Grouping**: Automatically groups similar exceptions using fingerprinting
- **Status Tracking**: Open, Resolved, Reopened, Ignored states
- **Occurrence Count**: Track how many times each error occurs
- **User Tracking**: Link exceptions to affected users
- **Comments**: Add notes to exceptions for team collaboration
- **Rate Limiting**: Prevent database flooding from repeated errors
- **Modern UI**: Beautiful Tailwind-styled dashboard
- **Stimulus JS**: Lightweight JavaScript interactions

## Requirements

- Ruby >= 3.0
- Rails >= 7.0, < 9.0
- Bun (for CSS bundling)
- Tailwind CSS via css-bundling-rails

## Installation

Add to your Gemfile:

```ruby
gem "rails_exception_log"
```

Run the install generator:

```bash
rails generate rails_exception_log:install
```

This will:
- Copy migrations to your app
- Add route to config/routes.rb

Then run migrations:

```bash
rails db:migrate
```

## Configuration

### Application Controller

```ruby
class ApplicationController < ActionController::Base
  include RailsExceptionLog::ExceptionLoggable
  rescue_from Exception, with: :log_exception_handler
end
```

### Routes

The generator adds this route:

```ruby
mount RailsExceptionLog::Engine => "/exceptions"
```

### Optional Configuration

Create an initializer `config/initializers/rails_exception_log.rb`:

```ruby
RailsExceptionLog.configure do |config|
  config.application_name = "My App"
  config.max_requests_per_minute = 100
  config.enable_user_tracking = true
  config.before_log_exception = ->(controller) {
    # Add custom authentication
    true
  }
  config.after_log_exception = ->(exception) {
    # Send notifications, etc.
  }
end
```

### Custom Exception Data

```ruby
class ApplicationController < ActionController::Base
  # Add custom data to exceptions
  self.exception_data = Proc.new { |controller|
    { user_id: controller.current_user&.id }
  }
  
  # Or use a method
  self.exception_data = :extra_exception_data
  
  def extra_exception_data
    { version: "1.0", environment: Rails.env }
  end
end
```

### Authentication

In your environment config:

```ruby
config.after_initialize do
  RailsExceptionLog::LoggedExceptionsController.class_eval do
    before_action :authenticate_admin!
  end
end
```

## Usage

### Dashboard

Visit `/exceptions` to view the exception dashboard.

### Actions

- **View**: Click on an exception to see details
- **Resolve**: Mark an exception as resolved
- **Reopen**: Reopen a resolved exception
- **Ignore**: Ignore an exception
- **Delete**: Delete an exception
- **Export**: Export exceptions as CSV

### Filtering

- By date range (Today, 7 days, 30 days)
- By status (Open, Resolved, Reopened, Ignored)
- By exception type
- By controller

## JavaScript Setup

Ensure your app has Stimulus configured. The gem includes a dropdown controller.

In your application layout, include the bundled assets:

```erb
<%= stylesheet_link_tag "rails_exception_log/application" %>
<%= javascript_include_tag "rails_exception_log/application" %>
```

## Rake Tasks

```bash
# Cleanup exceptions older than 30 days
rails rails_exception_log:cleanup

# Cleanup with custom days
rails rails_exception_log:cleanup[60]
```

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Build
bundle exec rake build
```

## License

MIT License