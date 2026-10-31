# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @original_config = RailsExceptionLog.configuration.dup
  end

  teardown do
    RailsExceptionLog.instance_variable_set(:@configuration, @original_config)
  end

  test "default configuration values" do
    config = RailsExceptionLog::Configuration.new
    assert_nil config.application_name
    assert_nil config.auth_block
    assert_nil config.exception_data
    assert_equal 30, config.per_page
    assert config.enabled
  end

  test "configure block sets values" do
    RailsExceptionLog.configure do |config|
      config.application_name = "MyApp"
      config.per_page = 50
      config.enabled = false
    end

    assert_equal "MyApp", RailsExceptionLog.configuration.application_name
    assert_equal 50, RailsExceptionLog.configuration.per_page
    assert_not RailsExceptionLog.configuration.enabled
  end

  test "configure block sets auth_block" do
    auth = ->(controller) { controller.current_user.present? }
    RailsExceptionLog.configure { |c| c.auth_block = auth }

    assert_equal auth, RailsExceptionLog.configuration.auth_block
  end

  test "configure block sets exception_data" do
    data = ->(_controller) { { user_id: 1 } }
    RailsExceptionLog.configure { |c| c.exception_data = data }

    assert_equal data, RailsExceptionLog.configuration.exception_data
  end

  test "application_name accessor on RailsExceptionLog module" do
    RailsExceptionLog.application_name = "TestApp"
    assert_equal "TestApp", RailsExceptionLog.application_name
    assert_equal "TestApp", RailsExceptionLog.configuration.application_name
  end

  test "configuration is a singleton" do
    config1 = RailsExceptionLog.configuration
    config2 = RailsExceptionLog.configuration
    assert_same config1, config2
  end
end
