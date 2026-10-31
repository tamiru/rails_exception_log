# frozen_string_literal: true

module RailsExceptionLog
  # Records unhandled exceptions from every request, including controllers
  # (and engine controllers) that never include ExceptionLoggable, then
  # re-raises so Rails renders its normal error page.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception # rubocop:disable Lint/RescueException -- re-raised below
      capture(env, exception) if exception.is_a?(StandardError)
      raise
    end

    private

    def capture(env, exception)
      return unless RailsExceptionLog.configuration.capture_requests

      controller = env["action_controller.instance"]
      unless controller.respond_to?(:request)
        request = ActionDispatch::Request.new(env)
        controller = RailsExceptionLog::Capture::Context.new(
          controller_path: "rack",
          action_name: request.request_method,
          request: request
        )
      end

      RailsExceptionLog::Capture.call(exception, controller: controller)
    rescue StandardError
      nil
    end
  end
end
