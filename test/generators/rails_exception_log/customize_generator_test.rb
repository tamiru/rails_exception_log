# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/rails_exception_log/customize_generator"

class RailsExceptionLog::Generators::CustomizeGeneratorTest < Rails::Generators::TestCase
  tests RailsExceptionLog::Generators::CustomizeGenerator
  destination Rails.root.join("tmp/generators")

  setup { prepare_destination }

  test "views are copied from the engine so they match the installed version" do
    run_generator ["--views-only"]

    engine_views = RailsExceptionLog::Engine.root.join("app/views/rails_exception_log/logged_exceptions")
    %w[index.html.erb _exceptions.html.erb _show.html.erb].each do |view|
      assert_file "app/views/rails_exception_log/logged_exceptions/#{view}", File.read(engine_views.join(view))
    end
  end

  test "the layout is copied verbatim, keeping its ERB for the app to render" do
    run_generator ["--layout-only"]

    assert_file "app/views/layouts/rails_exception_log/application.html.erb" do |content|
      assert_match(/<%= render "layouts\/rails_exception_log\/theme_script" %>/, content)
      assert_match(/<%= stylesheet_link_tag "rails_exception_log\/application"/, content)
    end
  end
end
