# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::ResolutionTest < ActiveSupport::TestCase
  Model = RailsExceptionLog::LoggedException

  setup do
    Model.delete_all
    @config = RailsExceptionLog.configuration
    @original = { after_regression: @config.after_regression, webhooks: @config.webhooks }
    @exception = Model.create!(exception_class: "RuntimeError", message: "boom", fingerprint: "fp-1",
                               occurrence_count: 3, controller_name: "orders", action_name: "create")
  end

  teardown do
    @config.after_regression = @original[:after_regression]
    @config.webhooks = @original[:webhooks]
  end

  test "resolve! marks the exception resolved and logs who did it" do
    @exception.resolve!(author: "ana@example.com")

    assert @exception.reload.resolved?
    refute @exception.regressed?
    refute @exception.active?
    assert_equal "ana@example.com", @exception.resolved_by
    assert_equal "Resolved", @exception.comments.recent.first.body
    assert_includes @exception.status_badges, { label: "Resolved", tone: "success" }
  end

  test "reopen! clears the resolution" do
    @exception.resolve!(author: "ana")
    @exception.reopen!(author: "ben")

    refute @exception.reload.resolved?
    assert_nil @exception.resolved_by
    assert @exception.active?
    assert_equal "Reopened", @exception.comments.recent.first.body
  end

  test "a resolved exception that happens again is reopened as a regression" do
    @exception.resolve!(author: "ana")

    record = Model.persist_capture(capture_attributes)

    assert_equal @exception.id, record.id
    record.reload
    refute record.resolved?
    assert record.regressed?
    assert_nil record.resolved_by
    assert_equal 4, record.occurrence_count
    assert_not_nil record.regressed_at
    assert_match(/Regressed/, record.comments.recent.first.body)
    assert_includes record.status_badges, { label: "Regression", tone: "danger" }
  end

  test "repeats of an unresolved exception are not regressions" do
    calls = []
    @config.after_regression = ->(exception) { calls << exception }

    record = Model.persist_capture(capture_attributes).reload

    refute record.regressed?
    assert_nil record.regressed_at
    assert_empty calls
  end

  test "resolving a regression clears the regression flag" do
    @exception.resolve!(author: "ana")
    Model.persist_capture(capture_attributes)

    @exception.reload.resolve!(author: "ana")

    refute @exception.reload.regressed?
    assert_nil @exception.regressed_at
  end

  test "a regression calls after_regression" do
    calls = []
    @config.after_regression = ->(exception) { calls << exception.id }
    @exception.resolve!(author: "ana")

    Model.persist_capture(capture_attributes)

    assert_equal [@exception.id], calls
  end

  test "a regression sends webhooks with the exception.regressed event" do
    @config.webhooks = ["https://hooks.example.com/abc"]
    payloads = []
    @exception.resolve!(author: "ana")

    with_webhook_delivery(->(url:, payload:, **) { payloads << [url, payload]; { success: true, status_code: 200, body: "" } }) do
      Model.persist_capture(capture_attributes)
    end

    assert_equal 1, payloads.size
    url, payload = payloads.first
    assert_equal "https://hooks.example.com/abc", url
    assert_equal "exception.regressed", payload[:event]
    assert_equal @exception.id, payload[:exception][:id]
    assert_equal 4, payload[:exception][:occurrence_count]
  end

  test "a muted exception is reopened quietly" do
    calls = []
    @config.after_regression = ->(exception) { calls << exception }
    @exception.resolve!(author: "ana")
    @exception.mute!(author: "ana")

    record = Model.persist_capture(capture_attributes).reload

    assert record.regressed?
    assert_empty calls
  end

  test "a failing regression notifier does not lose the occurrence" do
    @config.after_regression = ->(_exception) { raise "notifier down" }
    @exception.resolve!(author: "ana")

    record = Model.persist_capture(capture_attributes).reload

    assert record.regressed?
    assert_equal 4, record.occurrence_count
  end

  test "scopes split resolved, unresolved, regressed, and active" do
    resolved = Model.create!(exception_class: "A", fingerprint: "fp-2")
    resolved.resolve!(author: "ana")
    regressed = Model.create!(exception_class: "B", fingerprint: "fp-3", regressed_at: 1.hour.ago)

    assert_equal [resolved.id], Model.resolved.pluck(:id)
    assert_equal [@exception.id, regressed.id].sort, Model.unresolved.pluck(:id).sort
    assert_equal [regressed.id], Model.regressed.pluck(:id)
    refute_includes Model.active.pluck(:id), resolved.id
    assert_equal 1, Model.workflow_summary[:resolved]
    assert_equal 1, Model.workflow_summary[:regressed]
  end

  private

  def capture_attributes
    { "fingerprint" => "fp-1", "exception_class" => "RuntimeError", "message" => "boom again",
      "controller_name" => "orders", "action_name" => "create" }
  end

  def with_webhook_delivery(replacement)
    client = RailsExceptionLog::WebhookClient.singleton_class
    original = RailsExceptionLog::WebhookClient.method(:deliver)
    client.define_method(:deliver, &replacement)
    yield
  ensure
    client.define_method(:deliver, original)
  end
end
