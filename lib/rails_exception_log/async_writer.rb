# frozen_string_literal: true

module RailsExceptionLog
  # Writes captured exceptions on a single background thread so the request or
  # job that raised never waits on the database. The queue is bounded: when it
  # is full, new exceptions are dropped rather than growing memory. The thread
  # is restarted after fork (Puma/Unicorn workers) and drained at exit.
  class AsyncWriter
    STOP = Object.new.freeze
    DROP_LOG_EVERY = 100

    @instance = nil
    @instance_mutex = Mutex.new

    class << self
      def instance
        @instance_mutex.synchronize { @instance ||= new }
      end

      # Drains and stops the writer if one was started. Safe to call at exit.
      def shutdown(timeout: 5)
        writer = @instance_mutex.synchronize { @instance }
        writer&.shutdown(timeout: timeout)
      end

      # Test helper: stop the current writer and forget it.
      def reset!
        shutdown(timeout: 1)
        @instance_mutex.synchronize { @instance = nil }
      end
    end

    attr_reader :dropped_count

    def initialize
      @mutex = Mutex.new
      @idle = ConditionVariable.new
      reset_state
    end

    # Queues attributes from LoggedException.capture_attributes. Returns true
    # when queued and false when dropped because the queue is full.
    def enqueue(attributes)
      @mutex.synchronize do
        reset_state if @pid != Process.pid

        if @pending >= max_queue_size
          @dropped_count += 1
          log_drop if @dropped_count == 1 || (@dropped_count % DROP_LOG_EVERY).zero?
          return false
        end

        @pending += 1
        @queue << attributes
        ensure_thread
      end
      true
    end

    # Blocks until every queued exception has been written or +timeout+
    # seconds have passed. Returns true when the queue is empty.
    def flush(timeout: 5)
      deadline = monotonic_now + timeout
      @mutex.synchronize do
        while @pending.positive?
          remaining = deadline - monotonic_now
          return false if remaining <= 0

          @idle.wait(@mutex, remaining)
        end
      end
      true
    end

    def shutdown(timeout: 5)
      flush(timeout: timeout)
      thread = @mutex.synchronize do
        @queue << STOP if @thread&.alive?
        @thread
      end
      thread&.join(timeout)
    end

    def pending_count
      @mutex.synchronize { @pending }
    end

    private

    def reset_state
      @queue = Thread::Queue.new
      @thread = nil
      @pending = 0
      @dropped_count = 0
      @pid = Process.pid
    end

    def ensure_thread
      return if @thread&.alive?

      @thread = Thread.new { run }
      @thread.name = "rails_exception_log-writer" if @thread.respond_to?(:name=)
      @thread.report_on_exception = false
    end

    def run
      loop do
        attributes = @queue.pop
        break if attributes.equal?(STOP)

        begin
          write(attributes)
        ensure
          @mutex.synchronize do
            @pending -= 1 if @pending.positive?
            @idle.broadcast if @pending.zero?
          end
        end
      end
    end

    def write(attributes)
      RailsExceptionLog::Capture.without_capture do
        with_executor { RailsExceptionLog::LoggedException.persist_capture(attributes) }
      end
    rescue StandardError => e
      ::Rails.logger&.error("[RailsExceptionLog] Failed to write exception (#{e.class}: #{e.message})")
    end

    # The Rails executor makes autoloaded constants safe to use from this
    # thread and returns database connections to the pool afterwards.
    def with_executor(&block)
      executor = defined?(::Rails) && ::Rails.application&.executor
      executor ? executor.wrap(&block) : yield
    end

    def max_queue_size
      [RailsExceptionLog.configuration.async_queue_size.to_i, 1].max
    end

    def log_drop
      ::Rails.logger&.warn(
        "[RailsExceptionLog] Exception queue is full (#{max_queue_size}); " \
        "#{@dropped_count} exception(s) dropped so far"
      )
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
