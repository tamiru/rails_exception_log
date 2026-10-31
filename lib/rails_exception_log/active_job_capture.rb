# frozen_string_literal: true

module RailsExceptionLog
  # Records ActiveJob failures. The perform.active_job event only carries an
  # exception when it escaped the job, so attempts that retry_on schedules
  # again (or discard_on swallows) are not recorded; the final failure is.
  module ActiveJobCapture
    EVENT = "perform.active_job"
    ARGUMENTS_LIMIT = 1_000

    class << self
      def subscribe!
        return if @subscriber

        @subscriber = ActiveSupport::Notifications.subscribe(EVENT) do |event|
          handle(event.payload)
        end
      end

      def unsubscribe!
        ActiveSupport::Notifications.unsubscribe(@subscriber) if @subscriber
        @subscriber = nil
      end

      def handle(payload)
        exception = payload[:exception_object]
        job = payload[:job]
        return unless exception && job
        return unless RailsExceptionLog.configuration.capture_jobs

        RailsExceptionLog::Capture.call(
          exception,
          controller: RailsExceptionLog::Capture::Context.new(controller_path: job.class.name, action_name: "perform"),
          data: job_data(job)
        )
      end

      private

      def job_data(job)
        {
          job_class: job.class.name,
          job_id: job.job_id,
          provider_job_id: job.provider_job_id,
          queue_name: job.queue_name,
          executions: job.executions,
          enqueued_at: job.enqueued_at,
          arguments: job.arguments.inspect.truncate(ARGUMENTS_LIMIT)
        }.compact
      rescue StandardError
        { job_class: job.class.name }
      end
    end
  end
end
