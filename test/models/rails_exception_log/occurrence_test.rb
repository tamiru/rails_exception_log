# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::OccurrenceTest < ActiveSupport::TestCase
  setup do
    RailsExceptionLog::Occurrence.reset_availability!
    RailsExceptionLog::Occurrence.delete_all
    RailsExceptionLog::Comment.delete_all
    RailsExceptionLog::LoggedException.delete_all
    @attributes = { "exception_class" => "RuntimeError", "controller_name" => "orders",
                    "action_name" => "show", "message" => "boom", "fingerprint" => "fp-1" }
  end

  test "every capture records when it happened, also when folded into one row" do
    first = RailsExceptionLog::LoggedException.persist_capture(@attributes.merge("captured_at" => 2.days.ago))
    again = RailsExceptionLog::LoggedException.persist_capture(@attributes.merge("captured_at" => 1.hour.ago))

    assert_equal first.id, again.id
    assert_equal 2, again.reload.occurrence_count
    assert_equal 2, again.occurrences.count
  end

  test "a capture prunes that exception's history past the retention window" do
    exception = RailsExceptionLog::LoggedException.persist_capture(@attributes)
    exception.occurrences.create!(occurred_at: 45.days.ago)

    RailsExceptionLog::LoggedException.persist_capture(@attributes)

    assert_equal 2, exception.occurrences.count
    assert exception.occurrences.all? { |occurrence| occurrence.occurred_at > 30.days.ago }
  end

  test "daily_counts buckets the last seven days, oldest first, in UTC days" do
    now = Time.utc(2026, 11, 27, 12)
    exception = RailsExceptionLog::LoggedException.create!(exception_class: "RuntimeError")
    quiet = RailsExceptionLog::LoggedException.create!(exception_class: "QuietError")
    [now - 6.days, now - 1.hour, now - 2.hours, now - 8.days].each do |time|
      exception.occurrences.create!(occurred_at: time)
    end

    counts = RailsExceptionLog::Occurrence.daily_counts([exception.id, quiet.id], now: now)

    assert_equal [1, 0, 0, 0, 0, 0, 2], counts[exception.id]
    assert_equal [0] * 7, counts[quiet.id]
  end

  test "deleting exceptions in bulk takes their history and comments with them" do
    exception = RailsExceptionLog::LoggedException.persist_capture(@attributes)
    exception.add_comment(author: "ops", body: "seen")
    kept = RailsExceptionLog::LoggedException.persist_capture(@attributes.merge("fingerprint" => "fp-2"))

    deleted = RailsExceptionLog::LoggedException.delete_with_history(
      RailsExceptionLog::LoggedException.where(id: exception.id)
    )

    assert_equal 1, deleted
    assert_equal [kept.id], RailsExceptionLog::Occurrence.distinct.pluck(:logged_exception_id)
    assert_equal 0, RailsExceptionLog::Comment.count
  end

  test "capture still works when the history table has not been created yet" do
    RailsExceptionLog::Occurrence.instance_variable_set(:@available, false)
    exception = RailsExceptionLog::LoggedException.persist_capture(@attributes)

    assert exception.persisted?
    assert_equal({}, RailsExceptionLog::Occurrence.daily_counts([exception.id]))
    assert_equal 0, RailsExceptionLog::Occurrence.count
  ensure
    RailsExceptionLog::Occurrence.reset_availability!
  end
end
