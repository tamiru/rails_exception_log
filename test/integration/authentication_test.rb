# frozen_string_literal: true

require "test_helper"

class RailsExceptionLogAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @original_auth_block = RailsExceptionLog.configuration.auth_block
    @exception = RailsExceptionLog::LoggedException.create!(
      exception_class: "RuntimeError",
      controller_name: "users",
      action_name: "show",
      message: "Authentication coverage"
    )
  end

  teardown do
    RailsExceptionLog.configuration.auth_block = @original_auth_block
  end

  test "missing authentication block fails closed" do
    RailsExceptionLog.configuration.auth_block = nil

    get "/rails_exception_log/logged_exceptions"

    assert_response :forbidden
  end

  test "authentication block returning false is forbidden" do
    RailsExceptionLog.configuration.auth_block = ->(_controller) { false }

    get "/rails_exception_log/logged_exceptions"

    assert_response :forbidden
  end

  test "authentication block returning true receives the engine controller" do
    received_controller = nil
    RailsExceptionLog.configuration.auth_block = lambda do |controller|
      received_controller = controller
      true
    end

    get "/rails_exception_log/logged_exceptions"

    assert_response :success
    assert_instance_of RailsExceptionLog::LoggedExceptionsController, received_controller
  end

  test "workflow endpoints use global authentication" do
    RailsExceptionLog.configuration.auth_block = nil

    post "/rails_exception_log/logged_exceptions/#{@exception.id}/assign", params: { assigned_to: "attacker@example.test" }

    assert_response :forbidden
    assert_nil @exception.reload.assigned_to
  end

  test "source code endpoint uses global authentication" do
    RailsExceptionLog.configuration.auth_block = nil

    get "/rails_exception_log/source_code", params: { file: Rails.root.join("config/routes.rb").to_s, line: 1 }

    assert_response :forbidden
  end

  test "authentication errors fail closed" do
    RailsExceptionLog.configuration.auth_block = ->(_controller) { raise "authentication backend unavailable" }

    get "/rails_exception_log/logged_exceptions"

    assert_response :forbidden
  end
end
