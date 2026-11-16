# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::WorkflowResolutionTest < ActionDispatch::IntegrationTest
  setup do
    RailsExceptionLog.configure { |config| config.auth_block = ->(_controller) { true } }
    RailsExceptionLog::LoggedException.delete_all
    @exception = RailsExceptionLog::LoggedException.create!(
      exception_class: "RuntimeError", message: "boom", fingerprint: "fp-ctrl",
      controller_name: "orders", action_name: "create"
    )
  end

  test "resolve marks the exception resolved" do
    post "/rails_exception_log/logged_exceptions/#{@exception.id}/resolve", as: :json

    assert_response :success
    assert @exception.reload.resolved?
    assert_equal "ok", response.parsed_body["status"]
    assert_equal "anonymous", @exception.resolved_by
  end

  test "reopen clears the resolution" do
    @exception.resolve!(author: "ana")

    post "/rails_exception_log/logged_exceptions/#{@exception.id}/reopen"

    assert_redirected_to "/rails_exception_log/logged_exceptions/#{@exception.id}"
    refute @exception.reload.resolved?
  end

  test "resolve over turbo stream re-renders the workflow panel with a Reopen button" do
    post "/rails_exception_log/logged_exceptions/#{@exception.id}/resolve",
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "workflow-panel"
    assert_includes response.body, "Reopen"
    assert_includes response.body, "Resolved"
  end

  test "the status filter lists regressions" do
    @exception.update!(regressed_at: 1.hour.ago)
    other = RailsExceptionLog::LoggedException.create!(exception_class: "OtherError", message: "quiet", fingerprint: "fp-other")

    get "/rails_exception_log/logged_exceptions", params: { status_filter: "regressed" }

    assert_response :success
    assert_includes listed_ids, @exception.id
    refute_includes listed_ids, other.id
  end

  test "the status filter hides resolved exceptions when asking for unresolved ones" do
    @exception.resolve!(author: "ana")
    other = RailsExceptionLog::LoggedException.create!(exception_class: "OtherError", message: "open", fingerprint: "fp-other")

    get "/rails_exception_log/logged_exceptions", params: { status_filter: "unresolved" }

    assert_response :success
    assert_includes listed_ids, other.id
    refute_includes listed_ids, @exception.id
  end

  private

  # Ids of the exceptions linked from the list rows.
  def listed_ids
    response.body.scan(%r{/rails_exception_log/logged_exceptions/(\d+)"}).flatten.map(&:to_i).uniq
  end
end
