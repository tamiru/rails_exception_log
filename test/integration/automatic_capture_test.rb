# frozen_string_literal: true

require "test_helper"

class AutomaticCaptureTest < ActionDispatch::IntegrationTest
  SETTINGS = %i[capture_enabled capture_requests ignored_exceptions].freeze

  setup do
    @config = RailsExceptionLog.configuration
    @saved = SETTINGS.to_h { |name| [name, @config.public_send(name)] }
  end

  teardown do
    @saved.each { |name, value| @config.public_send(:"#{name}=", value) }
  end

  test "records exceptions from controllers that do not include the concern" do
    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      assert_raises(ArgumentError) { get "/failures/boom" }
    end

    record = RailsExceptionLog::LoggedException.order(:id).last
    assert_equal "ArgumentError", record.exception_class
    assert_equal "failures", record.controller_name
    assert_equal "show", record.action_name
    assert_includes record.request, "/failures/boom"
  end

  test "the dashboard shows the file and line where the exception was raised" do
    assert_raises(ArgumentError) { get "/failures/boom" }
    record = RailsExceptionLog::LoggedException.order(:id).last
    raise_line = File.readlines(Rails.root.join("app/controllers/failures_controller.rb"))
                     .index { |line| line.include?('raise ArgumentError, "dummy failure"') } + 1

    assert_equal "app/controllers/failures_controller.rb:#{raise_line}", record.location_label

    original_auth = @config.auth_block
    @config.auth_block = ->(_controller) { true }
    get "/rails_exception_log/logged_exceptions/#{record.id}"

    assert_response :success
    assert_select ".rn-location .rn-location-file", text: "app/controllers/failures_controller.rb"
    assert_select ".rn-location .rn-location-line", text: ":#{raise_line}"
    assert_select ".rn-location .source-line.is-error .line-content", text: /raise ArgumentError, "dummy failure"/
    assert_select ".rn-bt-app", minimum: 1

    get "/rails_exception_log/logged_exceptions"
    assert_select ".rn-row-location", text: "app/controllers/failures_controller.rb:#{raise_line}"
  ensure
    @config.auth_block = original_auth
  end

  test "records an exception once when both the concern and the middleware see it" do
    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      assert_raises(ArgumentError) { get "/concern_failures" }
    end

    assert_equal 1, RailsExceptionLog::LoggedException.order(:id).last.occurrence_count
  end

  test "skips ignored exceptions" do
    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      get "/failures/not_found"
    end
    assert_response :not_found
  end

  test "records ignored classes once they are removed from the ignore list" do
    @config.ignored_exceptions = []

    assert_difference -> { RailsExceptionLog::LoggedException.count }, 1 do
      get "/failures/not_found"
    end
  end

  test "request capture can be turned off" do
    @config.capture_requests = false

    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      assert_raises(ArgumentError) { get "/failures/boom" }
    end
  end

  test "capture_enabled turns off every capture path" do
    @config.capture_enabled = false

    assert_no_difference -> { RailsExceptionLog::LoggedException.count } do
      assert_raises(ArgumentError) { get "/concern_failures" }
    end
  end
end
