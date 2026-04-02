require 'digest'

module RailsExceptionLog
  module ExceptionLoggable
    extend ActiveSupport::Concern

    included do
      after_action :log_exception_to_db, if: :exception_loggable?
    end

    def log_exception_handler
      log_exception_to_db
      raise exception
    end

    private

    def exception_loggable?
      return false if exception.nil?
      return false if is_a?(RailsExceptionLog::LoggedExceptionsController)
      return false if ENV['RAILS_EXCEPTION_LOG_DISABLED'] == 'true'
      return false unless rate_limit_allow?

      true
    end

    def rate_limit_allow?
      return true if Rails.env.development?

      key = "exception_log_rate_limit:#{request&.remote_ip}"
      count = Rails.cache.fetch(key, expires_in: 1.minute) do
        0
      end

      max = RailsExceptionLog.max_requests_per_minute || 60
      return false if count >= max

      Rails.cache.write(key, count + 1, expires_in: 1.minute)
      true
    end

    def log_exception_to_db
      return unless exception || defined?(@exception) && @exception

      exc = exception || @exception
      return unless exc

      begin
        user = current_user if respond_to?(:current_user)

        logged_exception = RailsExceptionLog::LoggedException.create_or_update_with_fingerprint!(
          exc,
          request,
          user: user
        )

        if respond_to?(:exception_data)
          data = exception_data.is_a?(Proc) ? instance_exec(self, &exception_data) : send(exception_data)
          logged_exception.update!(exception_data: data) if data.present?
        end

        RailsExceptionLog.after_log_exception.call(logged_exception) if RailsExceptionLog.after_log_exception
      rescue StandardError => e
        Rails.logger.error "Failed to log exception: #{e.message}"
      end
    end

    def request_params_without_passwords
      return {} unless request&.params

      params_hash = request.params.deep_dup
      filter_passwords(params_hash)
      params_hash
    end

    def filter_passwords(hash)
      hash.each do |key, value|
        if key.to_s =~ /password|secret|token/i
          hash[key] = '[FILTERED]'
        elsif value.is_a?(Hash)
          filter_passwords(value)
        elsif value.is_a?(Array)
          value.each { |v| filter_passwords(v) if v.is_a?(Hash) }
        end
      end
      hash
    end
  end
end
