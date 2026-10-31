# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/rails_exception_log/install_generator"

class RailsExceptionLog::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests RailsExceptionLog::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination

    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), <<~RUBY
      Rails.application.routes.draw do
      end
    RUBY

    FileUtils.mkdir_p File.join(destination_root, "app/controllers")
    File.write File.join(destination_root, "app/controllers/application_controller.rb"), <<~RUBY
      class ApplicationController < ActionController::Base
      end
    RUBY
  end

  test "generates the complete RailsExceptionLog installation" do
    run_generator

    assert_migration "db/migrate/create_rails_exception_log_tables.rb"

    assert_file "config/initializers/rails_exception_log.rb" do |content|
      assert_match(/RailsExceptionLog\.configure/, content)
    end

    assert_file "config/routes.rb" do |content|
      assert_match(%r{mount RailsExceptionLog::Engine, at: "/rails_exception_log"}, content)
    end

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_match(/rescue_from StandardError, with: :log_exception_handler/, content)
      refute_match(/rescue_from Exception,/, content)
    end
  end

  test "does not duplicate an existing exception handler" do
    run_generator
    run_generator

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_equal 1, content.scan("log_exception_handler").length
    end
  end
end
