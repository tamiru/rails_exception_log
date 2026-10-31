# frozen_string_literal: true

module RailsExceptionLog
  # Subscriber for the Rails error reporter (Rails.error). Records errors from
  # `rails runner`, Rails.error.record/report, and any library that reports
  # through it. Handled errors (Rails.error.handle) are skipped unless
  # config.capture_handled_errors is true.
  class ErrorSubscriber
    # Rails reports unhandled request errors under this source; the
    # middleware records those with full request context first.
    REQUEST_SOURCE = "application.action_dispatch"

    def report(error, handled:, severity: :error, context: {}, source: nil)
      config = RailsExceptionLog.configuration
      return unless config.capture_rails_errors
      return if handled && !config.capture_handled_errors
      return if source == REQUEST_SOURCE && !config.capture_requests

      context = context.to_h
      controller = context[:controller] if context[:controller].respond_to?(:request)
      data = context.except(:controller).merge(error_source: source, severity: severity, handled: handled).compact

      RailsExceptionLog::Capture.call(error, controller: controller, data: data, source: source.presence || "rails.error")
    end
  end
end
