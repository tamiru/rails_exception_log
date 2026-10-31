# frozen_string_literal: true

module RailsExceptionLog
  # Raised by `bin/rails rails_exception_log:test` to record a sample exception.
  class TestException < StandardError; end

  # Single entry point for recording an exception. The controller concern, the
  # Rack middleware, the ActiveJob/Sidekiq/rake hooks, and the Rails.error
  # subscriber all go through here, so filtering, de-duplication, and the
  # sync/async decision live in one place.
  module Capture
    # Stands in for a controller when the exception did not come from a
    # request (jobs, rake tasks, runner scripts).
    Context = Struct.new(:controller_path, :action_name, :request, :current_user, keyword_init: true)

    SKIP_KEY = :rails_exception_log_skip_capture
    SYNC_KEY = :rails_exception_log_sync_capture

    @captured = ObjectSpace::WeakMap.new
    @mutex = Mutex.new

    class << self
      # Records +exception+ once. Returns the saved record when writing
      # synchronously, true when queued for the background writer, and nil
      # when the exception was skipped or capture failed.
      #
      # controller - a controller instance or Context (default: a Context
      #              built from +source+ and +action+).
      # data       - extra context to store with the record. When nil and the
      #              controller is a real controller, config.exception_data is used.
      def call(exception, controller: nil, data: nil, source: nil, action: nil)
        return unless capturable?(exception)
        return unless mark_captured(exception)

        controller ||= Context.new(controller_path: source.presence || "unknown", action_name: action)
        data = exception_data_for(controller) if data.nil?
        data = RailsExceptionLog.filter_sensitive_data(data.presence || {})

        RailsExceptionLog::Logger.error(exception, controller: loggable_controller(controller), extra: data)

        attributes = RailsExceptionLog::LoggedException.capture_attributes(controller, exception, data)
        return unless attributes

        if RailsExceptionLog.configuration.async_capture? && !Thread.current[SYNC_KEY]
          RailsExceptionLog::AsyncWriter.instance.enqueue(attributes)
        else
          without_capture { RailsExceptionLog::LoggedException.persist_capture(attributes) }
        end
      rescue StandardError => e
        log_failure(e)
        nil
      end

      # Resolves an exception_data setting (Symbol method name, Proc, or
      # callable) against a controller. Failures are recorded, not raised.
      def resolve_exception_data(controller, deliverer)
        case deliverer
        when nil then {}
        when Symbol then controller.send(deliverer)
        when Proc then deliverer.call(controller)
        else deliverer.respond_to?(:call) ? deliverer.call(controller) : {}
        end
      rescue StandardError => e
        { exception_data_error: e.class.name }
      end

      def ignored?(exception)
        names = Array(RailsExceptionLog.configuration.ignored_exceptions).map(&:to_s)
        return false if names.empty?

        exception.class.ancestors.any? { |ancestor| ancestor.name && names.include?(ancestor.name) }
      end

      def captured?(exception)
        @mutex.synchronize { @captured.key?(exception) }
      end

      # Writes synchronously on the current thread for the duration of the
      # block, so the caller gets the saved record back.
      def without_async
        previous = Thread.current[SYNC_KEY]
        Thread.current[SYNC_KEY] = true
        yield
      ensure
        Thread.current[SYNC_KEY] = previous
      end

      # Suppresses capture on the current thread, so errors raised while
      # writing a record are not captured again.
      def without_capture
        previous = Thread.current[SKIP_KEY]
        Thread.current[SKIP_KEY] = true
        yield
      ensure
        Thread.current[SKIP_KEY] = previous
      end

      private

      def capturable?(exception)
        exception.is_a?(StandardError) &&
          RailsExceptionLog.configuration.capture_enabled &&
          !Thread.current[SKIP_KEY] &&
          !ignored?(exception)
      end

      # The same exception object often passes several hooks (the concern,
      # then the middleware, then Rails.error), so remember which ones were
      # recorded. WeakMap lets them be garbage collected.
      def mark_captured(exception)
        @mutex.synchronize do
          return false if @captured.key?(exception)

          @captured[exception] = true
        end
        true
      end

      def exception_data_for(controller)
        return {} if controller.is_a?(Context)

        resolve_exception_data(controller, RailsExceptionLog.configuration.exception_data)
      end

      def loggable_controller(controller)
        controller unless controller.is_a?(Context) && controller.request.nil?
      end

      def log_failure(error)
        ::Rails.logger&.error("[RailsExceptionLog] Failed to capture exception (#{error.class}: #{error.message})")
      rescue StandardError
        nil
      end
    end
  end
end
