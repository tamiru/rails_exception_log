# frozen_string_literal: true

module RailsExceptionLog
  # Records exceptions raised by rake tasks once the Rails app is loaded
  # (tasks that depend on :environment). Prepended to Rake::Task.
  module RakeCapture
    def execute(args = nil)
      super
    rescue Exception => exception # rubocop:disable Lint/RescueException -- re-raised below
      RailsExceptionLog::RakeCapture.capture(name, exception) if exception.is_a?(StandardError)
      raise
    end

    class << self
      def install!
        return unless defined?(::Rake::Task)
        return if ::Rake::Task.ancestors.include?(self)

        ::Rake::Task.prepend(self)
      end

      def capture(task_name, exception)
        return unless RailsExceptionLog.configuration.capture_rake_tasks
        return unless defined?(::Rails) && ::Rails.application&.initialized?

        RailsExceptionLog::Capture.call(
          exception,
          controller: RailsExceptionLog::Capture::Context.new(controller_path: "rake", action_name: task_name),
          data: { task: task_name }
        )
      rescue StandardError
        nil
      end
    end
  end
end
