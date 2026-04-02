require 'digest'

module RailsExceptionLog
  module ExceptionLoggable
    extend ActiveSupport::Concern

    def log_exception_handler
      Rails.logger.info '=' * 50
      Rails.logger.info 'RAILS_EXCEPTION_LOG: Handler triggered!'
      Rails.logger.info "Exception: #{exception.inspect}"
      Rails.logger.info '=' * 50

      exc = exception
      return raise exc unless exc.present?
      return raise exc if is_a?(RailsExceptionLog::LoggedExceptionsController)
      return raise exc if ENV['RAILS_EXCEPTION_LOG_DISABLED'] == 'true'

      begin
        current_user if respond_to?(:current_user)

        logged_exception = RailsExceptionLog::LoggedException.create!(
          exception_class: exc.class.name,
          message: exc.message,
          backtrace: exc.backtrace&.join("\n"),
          controller_name: controller_name,
          action_name: action_name,
          request_method: request&.method&.to_s,
          request_path: request&.path,
          request_params: request&.parameters&.to_h,
          environment: Rails.env,
          last_occurred_at: Time.current
        )

        Rails.logger.info "RAILS_EXCEPTION_LOG: Created #{logged_exception.id}"
      rescue StandardError => e
        Rails.logger.error "RAILS_EXCEPTION_LOG Error: #{e.message}"
      end

      raise exc
    end
  end
end
