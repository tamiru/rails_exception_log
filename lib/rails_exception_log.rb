require 'rails_exception_log/engine'
require 'rails_exception_log/version'
require 'rails_exception_log/exception_loggable'

module RailsExceptionLog
  mattr_accessor :application_name, default: 'Rails Exception Log'

  mattr_accessor :before_log_exception do |_controller|
    true
  end

  mattr_accessor :after_log_exception do |logged_exception|
  end

  mattr_accessor :max_requests_per_minute, default: 60

  mattr_accessor :enable_user_tracking, default: true

  mattr_accessor :filter_parameters, default: %i[password secret token api_key]

  def self.configure
    yield self
  end
end

ActiveSupport.on_load(:action_controller_base) do
  include RailsExceptionLog::ExceptionLoggable
end
