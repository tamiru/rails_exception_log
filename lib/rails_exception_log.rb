require "rails"
require "active_support/parameter_filter"
require "turbo-rails"
require "stimulus-rails"
require "pagy"
require "ransack"
require "ipaddr"
require "socket"
require "open3"
require "rails_exception_log/version"
require "rails_exception_log/configuration"
require "rails_exception_log/logger"
require "rails_exception_log/database_adapter"
require "rails_exception_log/capture"
require "rails_exception_log/async_writer"
require "rails_exception_log/error_subscriber"
require "rails_exception_log/middleware"
require "rails_exception_log/active_job_capture"
require "rails_exception_log/sidekiq_capture"
require "rails_exception_log/rake_capture"
require "rails_exception_log/doctor"
require "rails_exception_log/engine"

module RailsExceptionLog
  DEFAULT_FILTER_PARAMETERS = %i[
    password passw passwd secret token api_key apikey authorization cookie session
  ].freeze

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Backward-compatible accessor for application_name
    def application_name
      configuration.application_name
    end

    def application_name=(value)
      configuration.application_name = value
    end

    # Convenience logger accessor
    def logger
      RailsExceptionLog::Logger
    end

    # Records an exception you rescued yourself, e.g.
    #
    #   rescue PaymentGateway::Timeout => e
    #     RailsExceptionLog.capture(e, data: { order_id: order.id })
    #
    # Returns the record (synchronous writes), true (queued), or nil (skipped).
    def capture(exception, data: {}, source: "manual", action: nil)
      Capture.call(exception, data: data, source: source, action: action)
    end

    def parameter_filter
      configured = defined?(::Rails) ? ::Rails.application.config.filter_parameters : []
      ActiveSupport::ParameterFilter.new(DEFAULT_FILTER_PARAMETERS + Array(configured))
    end

    def filter_sensitive_data(value)
      value = value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

      case value
      when Hash
        parameter_filter.filter(value)
      when Array
        value.map { |entry| filter_sensitive_data(entry) }
      else
        value
      end
    end
  end

  # Copyright (c) 2005 Jamis Buck
  #
  # Permission is hereby granted, free of charge, to any person obtaining
  # a copy of this software and associated documentation files (the
  # "Software"), to deal in the Software without restriction, including
  # without limitation the rights to use, copy, modify, merge, publish,
  # distribute, sublicense, and/or sell copies of the Software, and to
  # permit persons to whom the Software is furnished to do so, subject to
  # the following conditions:
  #
  # The above copyright notice and this permission notice shall be
  # included in all copies or substantial portions of the Software.
  #
  # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  # MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  # LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  # OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  # WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  module ExceptionLoggable
    def self.included(target)
      target.extend(ClassMethods)
      target.class_attribute :local_addresses, :exception_data

      target.local_addresses = [IPAddr.new("127.0.0.1")]
    end

    module ClassMethods
      def consider_local(*args)
        local_addresses.concat(args.flatten.map { |a| IPAddr.new(a) })
      end
    end

    def local_request?
      remote = IPAddr.new(request.remote_ip)
      !self.class.local_addresses.detect { |addr| addr.include?(remote) }.nil?
    end

    # we log the exception and raise it again, for the normal handling.
    def log_exception_handler(exception)
      if exception.is_a?(StandardError)
        begin
          log_exception(exception)
        rescue StandardError => logging_error
          Rails.logger&.error("[RailsExceptionLog] Failed to capture exception (#{logging_error.class})")
        end
      end
      raise exception
    end

    def rescue_action(exception)
      status = response_code_for_rescue(exception)
      if exception.is_a?(StandardError) && status != :not_found
        begin
          log_exception(exception)
        rescue StandardError => logging_error
          Rails.logger&.error("[RailsExceptionLog] Failed to capture exception (#{logging_error.class})")
        end
      end
      super
    end

    def log_exception(exception)
      return unless exception.is_a?(StandardError)

      # Support both the legacy class_attribute and the new configuration DSL
      deliverer = self.class.exception_data || RailsExceptionLog.configuration.exception_data
      data = Capture.resolve_exception_data(self, deliverer)

      Capture.call(exception, controller: self, data: data || {})
    end
  end
end
