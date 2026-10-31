require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  setup do
    @original_auth_block = RailsExceptionLog.configuration.auth_block
    RailsExceptionLog.configuration.auth_block = ->(_controller) { true }
  end

  teardown do
    RailsExceptionLog.configuration.auth_block = @original_auth_block
  end

  test "engine layout loads its prebuilt assets without importmap tags" do
    get "/rails_exception_log"

    assert_response :success
    assert_select "script[src*='rails_exception_log/application'][defer]", count: 1
    assert_select "script[type='importmap']", count: 0
    assert_select "link[href*='rails_exception_log/application'][rel='stylesheet']", count: 1
  end

  test "prebuilt JavaScript contains Turbo and namespaced Stimulus controllers" do
    asset = RailsExceptionLog::Engine.root.join("app/assets/javascripts/rails_exception_log/application.js").read

    assert_includes asset, "rails_exception_log-sidebar"
    assert_includes asset, "RailsExceptionLogStimulus"
    assert_match(/Turbo/, asset)
  end
end
