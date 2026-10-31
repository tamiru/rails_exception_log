# frozen_string_literal: true

# Test-only configuration: allow all requests during tests
Rails.application.config.to_prepare do
  RailsExceptionLog.configure do |config|
    config.auth_block = ->(_controller) { true }
    config.per_page = 30
  end
end
