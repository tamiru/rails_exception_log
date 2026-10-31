# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::LocationTest < ActiveSupport::TestCase
  Model = RailsExceptionLog::LoggedException

  test "parses Ruby 3.4+ frames stored with the RAILS_ROOT placeholder" do
    frame = Model.parse_backtrace_line(
      "[RAILS_ROOT]/engines/estudent/app/views/estudent/books/show.html.erb:10:in 'block in _show_html_erb___123'"
    )

    assert_equal "engines/estudent/app/views/estudent/books/show.html.erb", frame[:file]
    assert_equal 10, frame[:line]
    assert_equal "block in _show_html_erb___123", frame[:method]
    assert frame[:app]
  end

  test "parses Ruby 3.3 frames with backtick quotes" do
    frame = Model.parse_backtrace_line("[RAILS_ROOT]/app/models/order.rb:42:in `charge!'")

    assert_equal ["app/models/order.rb", 42, "charge!", true], frame.values_at(:file, :line, :method, :app)
  end

  test "treats absolute paths inside Rails.root as app code" do
    frame = Model.parse_backtrace_line("#{Rails.root}/app/jobs/sync_job.rb:7:in 'SyncJob#perform'")

    assert_equal "app/jobs/sync_job.rb", frame[:file]
    assert frame[:app]
  end

  test "does not treat gems, vendor, or bin as app code" do
    assert_not Model.parse_backtrace_line("/usr/lib/ruby/gems/rack-3.2/lib/rack/head.rb:15:in 'Rack::Head#call'")[:app]
    assert_not Model.parse_backtrace_line("[RAILS_ROOT]/vendor/bundle/foo.rb:1:in 'x'")[:app]
    assert_not Model.parse_backtrace_line("[RAILS_ROOT]/bin/rails:4:in '<main>'")[:app]
  end

  test "parses frames without a method and rejects non-frames" do
    assert_equal ["app/models/a.rb", 3, nil], Model.parse_backtrace_line("[RAILS_ROOT]/app/models/a.rb:3").values_at(:file, :line, :method)
    assert_nil Model.parse_backtrace_line("not a frame")
    assert_nil Model.parse_backtrace_line(nil)
  end

  test "location is the first application frame" do
    record = Model.new(backtrace: [
      "/gems/actionpack/lib/abstract_controller/base.rb:215:in 'process'",
      "[RAILS_ROOT]/app/services/billing.rb:18:in 'Billing#charge'",
      "[RAILS_ROOT]/app/controllers/orders_controller.rb:9:in 'OrdersController#create'"
    ].join("\n"))

    assert_equal "app/services/billing.rb:18", record.location_label
    assert_equal "Billing#charge", record.location_method
  end

  test "location names the app method when a core method raised on the same line" do
    record = Model.new(backtrace: [
      "[RAILS_ROOT]/app/controllers/orders_controller.rb:4:in 'Hash#fetch'",
      "[RAILS_ROOT]/app/controllers/orders_controller.rb:4:in 'OrdersController#show'",
      "[RAILS_ROOT]/app/controllers/application_controller.rb:12:in 'around'"
    ].join("\n"))

    assert_equal "app/controllers/orders_controller.rb:4", record.location_label
    assert_equal "OrdersController#show", record.location_method
  end

  test "location falls back to the first frame without app code" do
    record = Model.new(backtrace: "/gems/rack/lib/rack/head.rb:15:in 'Rack::Head#call'")

    assert_equal "/gems/rack/lib/rack/head.rb:15", record.location_label
    assert_not record.location[:app]
  end

  test "location hides compiled template method names" do
    record = Model.new(backtrace: "[RAILS_ROOT]/app/views/orders/show.html.erb:4:in '_app_views_orders_show_html_erb___99'")

    assert_equal "app/views/orders/show.html.erb:4", record.location_label
    assert_nil record.location_method
  end

  test "no backtrace means no location" do
    assert_nil Model.new(backtrace: nil).location_label
  end
end
