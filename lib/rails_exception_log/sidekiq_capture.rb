# frozen_string_literal: true

module RailsExceptionLog
  # Sidekiq error handler. Records failures of plain Sidekiq jobs; ActiveJob
  # jobs running on Sidekiq are already recorded by ActiveJobCapture and the
  # same exception is not recorded twice.
  module SidekiqCapture
    ARGUMENTS_LIMIT = 1_000

    # Sidekiq 7 calls handlers with (exception, context, config); Sidekiq 6
    # with (exception, context).
    HANDLER = lambda do |exception, context, _config = nil|
      RailsExceptionLog::SidekiqCapture.handle(exception, context)
    end

    class << self
      def install!
        return unless defined?(::Sidekiq) && ::Sidekiq.respond_to?(:configure_server)

        ::Sidekiq.configure_server do |config|
          config.error_handlers << HANDLER unless config.error_handlers.include?(HANDLER)
        end
      end

      def handle(exception, context)
        return unless RailsExceptionLog.configuration.capture_sidekiq

        job = job_hash(context)
        job_class = job["wrapped"] || job["class"] || "Sidekiq"

        RailsExceptionLog::Capture.call(
          exception,
          controller: RailsExceptionLog::Capture::Context.new(controller_path: job_class.to_s, action_name: "perform"),
          data: {
            job_class: job_class,
            job_id: job["jid"],
            queue_name: job["queue"],
            retry_count: job["retry_count"],
            arguments: job["args"]&.inspect&.truncate(ARGUMENTS_LIMIT)
          }.compact
        )
      end

      private

      def job_hash(context)
        return {} unless context.respond_to?(:[])

        job = context[:job] || context["job"]
        job.is_a?(Hash) ? job.transform_keys(&:to_s) : {}
      rescue StandardError
        {}
      end
    end
  end
end
