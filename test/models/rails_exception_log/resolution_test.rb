# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::ResolutionTest < ActiveSupport::TestCase
  setup do
    RailsExceptionLog::Comment.delete_all
    RailsExceptionLog::Occurrence.delete_all
    RailsExceptionLog::LoggedException.delete_all
    @attributes = { "exception_class" => "RuntimeError", "message" => "boom", "fingerprint" => "fp-res" }
    @exception = RailsExceptionLog::LoggedException.persist_capture(@attributes)
  end

  test "resolve marks it fixed with who did it, and reopen undoes that" do
    @exception.resolve!(author: "amina")

    assert @exception.resolved?
    assert_equal "amina", @exception.resolved_by
    assert_includes RailsExceptionLog::LoggedException.resolved, @exception

    @exception.reopen!(author: "amina")

    assert_not @exception.resolved?
    assert_not @exception.regressed?
    assert_equal %w[Resolved Reopened], @exception.comments.order(:id).pluck(:body)
  end

  test "a resolved exception that happens again reopens itself as regressed" do
    @exception.resolve!(author: "amina")

    again = RailsExceptionLog::LoggedException.persist_capture(@attributes.merge("captured_at" => 1.minute.from_now))

    assert_equal @exception.id, again.id
    assert_not again.resolved?
    assert again.regressed?
    assert_equal 2, again.occurrence_count
    assert_includes RailsExceptionLog::LoggedException.regressed, again
    assert_equal "Regressed — seen again after being resolved", again.comments.order(:id).last.body
    assert_includes again.status_badges.pluck(:label), "Regressed"
  end

  test "repeats of an unresolved exception are not regressions" do
    again = RailsExceptionLog::LoggedException.persist_capture(@attributes)

    assert_not again.regressed?
    assert_equal 0, again.comments.count
  end

  test "resolving a regression clears the flag" do
    @exception.resolve!
    RailsExceptionLog::LoggedException.persist_capture(@attributes)
    @exception.reload.resolve!

    assert_not @exception.regressed?
    assert_empty RailsExceptionLog::LoggedException.regressed
  end
end
