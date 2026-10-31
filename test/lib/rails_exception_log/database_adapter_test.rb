# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::DatabaseAdapterTest < ActiveSupport::TestCase
  test "detects the active adapter and reports its version" do
    assert_includes %i[sqlite postgresql mysql], RailsExceptionLog::DatabaseAdapter.family
    refute_empty RailsExceptionLog::DatabaseAdapter.database_version.to_s
  end

  test "builds portable SQLite time expressions" do
    connection = FakeDatabaseConnection.new("SQLite3")

    assert_equal "strftime('%Y-%m-%d %H:00', \"created_at\")",
      RailsExceptionLog::DatabaseAdapter.time_bucket_expression(connection: connection)
    assert_equal "CAST(strftime('%H', \"created_at\") AS INTEGER)",
      RailsExceptionLog::DatabaseAdapter.time_component_expression(component: :hour, connection: connection)
    assert_equal "CAST(strftime('%w', \"created_at\") AS INTEGER)",
      RailsExceptionLog::DatabaseAdapter.time_component_expression(component: :weekday, connection: connection)
  end

  test "builds PostgreSQL and MySQL time expressions" do
    postgres = FakeDatabaseConnection.new("PostgreSQL")
    mysql = FakeDatabaseConnection.new("Mysql2")

    assert_match(/DATE_TRUNC/, RailsExceptionLog::DatabaseAdapter.time_bucket_expression(connection: postgres))
    assert_match(/EXTRACT\(DOW/, RailsExceptionLog::DatabaseAdapter.time_component_expression(component: :weekday, connection: postgres))
    assert_match(/DATE_FORMAT/, RailsExceptionLog::DatabaseAdapter.time_bucket_expression(connection: mysql))
    assert_match(/DAYOFWEEK/, RailsExceptionLog::DatabaseAdapter.time_component_expression(component: :weekday, connection: mysql))
  end
end

class FakeDatabaseConnection
  attr_reader :adapter_name

  def initialize(adapter_name)
    @adapter_name = adapter_name
  end

  def quote_column_name(name)
    %Q{"#{name}"}
  end
end
