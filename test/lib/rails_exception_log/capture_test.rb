# frozen_string_literal: true

require "test_helper"
require "rake"

class CaptureTestFailingJob < ActiveJob::Base
  def perform(order_id)
    raise ArgumentError, "job failed for #{order_id}"
  end
end

class CaptureTestRetriedJob < ActiveJob::Base
  retry_on ArgumentError, attempts: 3, wait: 0

  def perform
    raise ArgumentError, "temporary failure"
  end
end

class RailsExceptionLog::CaptureTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  SETTINGS = %i[
    capture_enabled capture_jobs capture_sidekiq capture_rake_tasks capture_rails_errors
    capture_handled_errors ignored_exceptions async_capture async_queue_size
  ].freeze

  # Writer whose thread never starts, so queued items stay queued.
  class PausedWriter < RailsExceptionLog::AsyncWriter
    private

    def ensure_thread; end
  end

  setup do
    @config = RailsExceptionLog.configuration
    @saved = SETTINGS.to_h { |name| [name, @config.public_send(name)] }
  end

  teardown do
    RailsExceptionLog::AsyncWriter.reset!
    @saved.each { |name, value| @config.public_send(:"#{name}=", value) }
  end

  test "records a failed ActiveJob with job context" do
    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      assert_raises(ArgumentError) { CaptureTestFailingJob.perform_now(42) }
    end

    record = latest_record
    assert_equal "CaptureTestFailingJob", record.controller_name
    assert_equal "perform", record.action_name
    assert_equal "CaptureTestFailingJob", record.local_variables["job_class"]
    assert_includes record.local_variables["arguments"], "42"
  end

  test "does not record job attempts that retry_on will retry" do
    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      CaptureTestRetriedJob.perform_now
    end
    assert_enqueued_jobs 1, only: CaptureTestRetriedJob
  end

  test "job capture can be turned off" do
    @config.capture_jobs = false

    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      assert_raises(ArgumentError) { CaptureTestFailingJob.perform_now(1) }
    end
  end

  test "records unhandled errors reported to Rails.error" do
    error = raised(RuntimeError, "runner failed")

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      Rails.error.report(error, handled: false, source: "application.runner")
    end

    record = latest_record
    assert_equal "application.runner", record.controller_name
    assert_equal "application.runner", record.local_variables["error_source"]
  end

  test "skips handled Rails.error reports unless configured" do
    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      Rails.error.handle { raise "handled quietly" }
    end

    @config.capture_handled_errors = true
    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      Rails.error.handle { raise "handled but recorded" }
    end
  end

  test "records Sidekiq job failures from the error handler" do
    error = raised(ArgumentError, "sidekiq failed")
    context = { job: { "class" => "HardWorker", "jid" => "abc123", "queue" => "critical", "args" => [7] } }

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      RailsExceptionLog::SidekiqCapture::HANDLER.call(error, context, nil)
    end

    record = latest_record
    assert_equal "HardWorker", record.controller_name
    assert_equal "abc123", record.local_variables["job_id"]
    assert_equal "critical", record.local_variables["queue_name"]
  end

  test "Sidekiq handler accepts the two-argument form and prefers the wrapped ActiveJob class" do
    error = raised(ArgumentError, "wrapped failed")

    RailsExceptionLog::SidekiqCapture::HANDLER.call(
      error, { job: { "class" => "Sidekiq::ActiveJob::Wrapper", "wrapped" => "ReportJob" } }
    )

    assert_equal "ReportJob", latest_record.controller_name
  end

  test "records rake task failures" do
    RailsExceptionLog::RakeCapture.install!
    task = Rake::Task.define_task(:capture_test_failure) { raise ArgumentError, "rake failed" }

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      assert_raises(ArgumentError) { task.execute }
    end

    record = latest_record
    assert_equal "rake", record.controller_name
    assert_equal "capture_test_failure", record.action_name
  ensure
    Rake::Task.tasks.delete(task) if task
    Rake.application.instance_variable_get(:@tasks)&.delete("capture_test_failure")
  end

  test "records manually rescued exceptions" do
    error = raised(IOError, "gateway timeout")

    record = RailsExceptionLog.capture(error, data: { order_id: 9, password: "secret" })

    assert_equal "IOError", record.exception_class
    assert_equal "manual", record.controller_name
    assert_equal 9, record.local_variables["order_id"]
    assert_equal "[FILTERED]", record.local_variables["password"]
  end

  test "records the same exception object only once" do
    error = raised(ArgumentError, "seen twice")

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      RailsExceptionLog.capture(error)
      RailsExceptionLog.capture(error)
    end
  end

  test "repeated failures increase the occurrence count of one record" do
    2.times { RailsExceptionLog.capture(raised(ArgumentError, "same place")) }

    assert_equal 2, latest_record.occurrence_count
  end

  test "ignored exceptions match subclasses" do
    @config.ignored_exceptions = ["ArgumentError"]
    error = raised(Class.new(ArgumentError), "subclass")

    assert_nil RailsExceptionLog.capture(error)
  end

  test "async capture writes on the background thread" do
    @config.async_capture = true
    writer = RailsExceptionLog::AsyncWriter.instance

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      assert_equal true, RailsExceptionLog.capture(raised(ArgumentError, "written later"))
      assert writer.flush(timeout: 5)
    end
    assert_equal "ArgumentError", latest_record.exception_class
  end

  test "async writer drops exceptions when its queue is full" do
    @config.async_queue_size = 1
    writer = PausedWriter.new

    assert writer.enqueue({ "fingerprint" => "a" })
    assert_not writer.enqueue({ "fingerprint" => "b" })
    assert_equal 1, writer.dropped_count
    assert_equal 1, writer.pending_count
  end

  test "a failed background write is logged and not captured again" do
    @config.async_capture = true
    writer = RailsExceptionLog::AsyncWriter.instance

    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      writer.enqueue({ "fingerprint" => "bad", "not_a_column" => true })
      assert writer.flush(timeout: 5)
    end
  end

  test "async capture defaults to off in the test environment" do
    @config.async_capture = nil
    assert_not @config.async_capture?

    @config.async_capture = true
    assert @config.async_capture?
  end

  private

  def raised(klass, message)
    raise klass, message
  rescue klass => e
    e
  end

  def latest_record
    RailsExceptionLog::LoggedException.order(:updated_at, :id).last
  end
end
