# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::DoctorTest < ActiveSupport::TestCase
  setup do
    @config = RailsExceptionLog.configuration
    @original_auth = @config.auth_block
    @manifest = Rails.root.join("public/assets/.manifest.json")
  end

  teardown do
    @config.auth_block = @original_auth
    FileUtils.rm_rf(Rails.root.join("public/assets"))
  end

  test "a correctly installed app is healthy" do
    @config.auth_block = ->(_controller) { true }
    doctor = RailsExceptionLog::Doctor.new
    doctor.run

    assert doctor.healthy?, report(doctor)
    assert_equal "/rails_exception_log", doctor.dashboard_path
    assert check(doctor, "Database tables").ok?
    assert check(doctor, "Capture").detail.include?("requests")
  end

  test "finds the engine when ordinary controller routes come first" do
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw do
      get "up", to: "failures#show"
      mount RailsExceptionLog::Engine, at: "/errors"
    end
    app = Struct.new(:routes, :middleware).new(routes, Rails.application.middleware)

    assert_equal "/errors", Timeout.timeout(5) { RailsExceptionLog::Doctor.new(app).dashboard_path }
  end

  test "warns, without failing, when the dashboard has no auth_block" do
    @config.auth_block = nil
    doctor = RailsExceptionLog::Doctor.new
    doctor.run

    assert_equal :warn, check(doctor, "Dashboard access").status
    assert doctor.healthy?
  end

  test "fails when a precompiled manifest is missing the dashboard assets" do
    FileUtils.mkdir_p(@manifest.dirname)
    File.write(@manifest, '{"application.css":"application-abc.css"}')
    doctor = RailsExceptionLog::Doctor.new
    doctor.run

    stale = check(doctor, "Precompiled assets")
    assert stale.failed?
    assert_match(/assets:precompile/, stale.fix)
    assert_not doctor.healthy?
  end

  test "report prints each check and returns the overall result" do
    @config.auth_block = ->(_controller) { true }
    io = StringIO.new

    assert RailsExceptionLog::Doctor.new.report(io)
    assert_match(/RailsExceptionLog #{Regexp.escape(RailsExceptionLog::VERSION)}/, io.string)
    assert_match(/✓ Dashboard route: \/rails_exception_log/, io.string)
  end

  private

  def check(doctor, name)
    doctor.checks.find { |c| c.name == name } || flunk("no #{name} check in:\n#{report(doctor)}")
  end

  def report(doctor)
    doctor.checks.map { |c| "#{c.status} #{c.name}: #{c.detail}" }.join("\n")
  end
end
