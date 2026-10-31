# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/rails_exception_log/install_generator"

class RailsExceptionLog::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests RailsExceptionLog::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination

    write "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
      end
    RUBY
    write "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < ActionController::Base
      end
    RUBY
    write "Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem "rails"
      gem "rails_exception_log"
    RUBY
  end

  test "first install creates the migration, initializer, and route" do
    run_generator

    assert_migration "db/migrate/create_rails_exception_log_tables.rb" do |content|
      assert_match(/^class CreateRailsExceptionLogTables < ActiveRecord::Migration\[\d+\.\d+\]$/, content)
      assert_nothing_raised { RubyVM::InstructionSequence.compile(content) }
    end
    assert_file "config/initializers/rails_exception_log.rb", /RailsExceptionLog\.configure/
    assert_file "config/routes.rb", %r{mount RailsExceptionLog::Engine, at: "/rails_exception_log"}
  end

  test "does not touch controllers: the middleware records request errors" do
    run_generator

    assert_file "app/controllers/application_controller.rb" do |content|
      assert_no_match(/rescue_from|log_exception_handler|ExceptionLoggable/, content)
    end
  end

  test "running again after an update changes nothing" do
    run_generator
    initializer = File.read(path("config/initializers/rails_exception_log.rb"))

    output = run_generator

    assert_equal 1, Dir[path("db/migrate/*_create_rails_exception_log_tables.rb")].size
    assert_equal 1, File.read(path("config/routes.rb")).scan("RailsExceptionLog::Engine").size
    assert_equal initializer, File.read(path("config/initializers/rails_exception_log.rb"))
    assert_match(/skip.*migration already present/, output)
  end

  test "keeps a customized initializer" do
    write "config/initializers/rails_exception_log.rb", "# my settings\n"

    run_generator

    assert_file "config/initializers/rails_exception_log.rb", "# my settings\n"
  end

  test "converts a rails_nexus project" do
    write "db/migrate/20260101000000_create_rails_nexus_tables.rb", "class CreateRailsNexusTables; end\n"
    write "config/routes.rb", <<~RUBY
      Rails.application.routes.draw do
        mount RailsNexus::Engine, at: '/rails_nexus'
      end
    RUBY
    write "config/initializers/rails_nexus.rb", <<~RUBY
      RailsNexus.configure do |config|
        config.sidebar_links = [{ label: "GitHub", url: "https://github.com/tamiru/rails_nexus" }]
      end
      RailsNexus::LoggedExceptionsController.helper ApplicationHelper
    RUBY
    write "app/controllers/application_controller.rb", <<~RUBY
      class ApplicationController < ActionController::Base
        include RailsNexus::ExceptionLoggable
      end
    RUBY
    write "app/helpers/menus_helper.rb", "LINK = '/rails_nexus'\n"
    write "Gemfile", <<~RUBY
      source "https://rubygems.org"
      gem 'rails_nexus'
      gem "rails_exception_log"
    RUBY

    run_generator

    assert_migration "db/migrate/rename_rails_nexus_tables_to_rails_exception_log.rb" do |content|
      assert_match(/ActiveRecord::Migration\[\d+\.\d+\]$/, content)
      assert_match(/rename_table old_name, new_name/, content)
    end
    assert_no_migration "db/migrate/create_rails_exception_log_tables.rb"
    assert_file "config/routes.rb" do |content|
      assert_match(%r{^  mount RailsExceptionLog::Engine, at: "/rails_exception_log"$}, content)
      assert_no_match(/RailsNexus/, content)
    end
    assert_no_file "config/initializers/rails_nexus.rb"
    assert_file "config/initializers/rails_exception_log.rb" do |content|
      assert_match(/RailsExceptionLog\.configure/, content)
      assert_match(/RailsExceptionLog::LoggedExceptionsController\.helper/, content)
      assert_match(%r{github\.com/tamiru/rails_exception_log}, content)
    end
    assert_file "app/controllers/application_controller.rb", /include RailsExceptionLog::ExceptionLoggable/
    assert_file "app/helpers/menus_helper.rb", "LINK = '/rails_exception_log'\n"
    assert_file "Gemfile" do |content|
      assert_no_match(/rails_nexus/, content)
      assert_match(/gem "rails_exception_log"/, content)
    end
  end

  test "keeps the rails_nexus gem when backup_nexus still needs it" do
    write "Gemfile", <<~RUBY
      gem 'rails_nexus'
      gem 'backup_nexus'
      gem "rails_exception_log"
    RUBY

    run_generator

    assert_file "Gemfile", /gem 'rails_nexus'/
  end

  private

  def path(relative)
    File.join(destination_root, relative)
  end

  def write(relative, content)
    FileUtils.mkdir_p(File.dirname(path(relative)))
    File.write(path(relative), content)
  end
end
