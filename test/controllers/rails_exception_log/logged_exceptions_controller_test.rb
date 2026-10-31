# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::LoggedExceptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Ensure auth is configured for tests
    RailsExceptionLog.configure do |config|
      config.auth_block = ->(_controller) { true }
    end

    RailsExceptionLog::LoggedException.delete_all
    @exception = RailsExceptionLog::LoggedException.create!(
      exception_class: "RuntimeError",
      controller_name: "users",
      action_name: "show",
      message: "Test error message",
      backtrace: "app/test.rb:1",
      request: "GET /test",
      environment: "Rails: test",
      platform: "api",
      priority: "critical",
      occurrence_count: 12,
      fingerprint: "abc123diagnostic",
      app_version: "4.2.1",
      local_variables: { request_id: "request-123" },
      instance_variables: { operation: "checkout" },
      assigned_to: "ops@example.com",
      created_at: Time.current
    )
  end

  test "index returns success" do
    get "/rails_exception_log/logged_exceptions"
    assert_response :success
  end

  test "index displays exceptions" do
    get "/rails_exception_log/logged_exceptions"
    assert_select "table"
    assert_select "span", text: "RuntimeError"
    assert_select "table.rn-exceptions-table td.rn-col-message .rn-msg[title='Test error message']"
    assert_select "th.sortable a", minimum: 5
    assert_select "th.rn-col-platform, th.rn-col-workflow", count: 0
    assert_select "select[name='q[priority_eq]']", count: 1
  end

  test "index renders the responsive application shell" do
    get "/rails_exception_log/logged_exceptions"

    assert_select "body[data-controller~='rails_exception_log-sidebar']"
    assert_select "meta[name='turbo-prefetch'][content='false']"
    assert_select "aside#rn-desktop-sidebar[data-rails_exception_log-sidebar-target='sidebar']"
    assert_select "button[data-action='click->rails_exception_log-sidebar#toggle'][data-rails_exception_log-sidebar-target='toggleButton'][aria-controls~='rn-desktop-sidebar'][aria-controls~='rn-mobile-sidebar']"
    assert_select "#rn-mobile-sidebar[data-rails_exception_log-sidebar-target='drawer']"
    assert_select "button#rn-shortcuts-button[data-action='click->rails_exception_log-sidebar#toggleShortcuts'][aria-haspopup='dialog']"
    assert_select ".rn-shortcuts-overlay[role='dialog'][aria-labelledby='rn-shortcuts-title']"
    assert_select "section.rn-card.rn-exceptions-panel", count: 1
    assert_select ".rn-exceptions-panel > .rn-exceptions-main table.rn-exceptions-table"
    assert_select ".rn-exceptions-panel > .rn-exceptions-main > details.rn-filter-disclosure[open]", count: 1
    assert_select ".rn-exceptions-panel #exceptions-content.rn-exceptions-results", count: 1
    assert_select ".rn-table-overview", count: 0
    assert_select ".rn-exceptions-rail", count: 0
    assert_select "#activity[hidden]", count: 1
    assert_select ".rn-sidebar details.rn-nav-section", count: 2
    assert_select ".rn-sidebar details.rn-nav-section[open] > summary.rn-nav-section-toggle", text: /Monitor/, count: 1
    assert_select ".rn-sidebar summary[data-action]", count: 0
    assert_select ".rn-sidebar details[data-action='toggle->rails_exception_log-sidebar#closeOtherMenus']", count: 2
    assert_select ".rn-mobile-sidebar nav[aria-label='RailsExceptionLog navigation']"
    assert_select ".rn-mobile-sidebar details.rn-nav-section", count: 2
    assert_select "main.rn-main.overflow-y-auto", count: 0
    assert_select ".rn-footer a[href='https://github.com/tamiru']", text: "Tamiru Hailu"
    assert_select ".rn-footer a[href='https://github.com/tamiru/rails_exception_log']", text: /GitHub/
  end

  test "index paginates with pagy" do
    25.times do |index|
      RailsExceptionLog::LoggedException.create!(
        exception_class: "Error#{index}", controller_name: "jobs", action_name: "run",
        message: "Error #{index}"
      )
    end

    get "/rails_exception_log/logged_exceptions", params: { per_page: 25, page: 2 }

    assert_response :success
    assert_select "tbody[data-rails_exception_log-target='exceptionList'] tr", count: 1
    assert_select ".rn-pagination .series-nav"
    assert_select "p", text: /Showing 26\s+to 26\s+of 26/
  end

  test "ransack filters across advanced exception fields" do
    RailsExceptionLog::LoggedException.create!(
      exception_class: "ArgumentError", controller_name: "posts", action_name: "create",
      message: "Different failure", platform: "web", priority: "low"
    )

    get "/rails_exception_log/logged_exceptions/query", params: {
      q: { platform_eq: "api", priority_eq: "critical", message_cont: "Test error" }
    }

    assert_response :success
    assert_select ".rn-exception-name", text: "RuntimeError", count: 1
    assert_select ".rn-exception-name", text: "ArgumentError", count: 0
  end

  test "ransack sorts exception table" do
    RailsExceptionLog::LoggedException.create!(
      exception_class: "ArgumentError", controller_name: "posts", action_name: "create",
      message: "Different failure"
    )

    get "/rails_exception_log/logged_exceptions/query", params: { q: { s: "exception_class asc" } }

    assert_response :success
    assert_select ".rn-exception-name" do |names|
      assert_equal(["ArgumentError", "RuntimeError"], names.map { |node| node.text.strip })
    end
  end

  test "index skips advanced controls omitted by a host ransack allowlist" do
    attributes = RailsExceptionLog::LoggedException.ransackable_attributes - ["priority"]
    singleton = RailsExceptionLog::LoggedException.singleton_class
    original = singleton.instance_method(:ransackable_attributes)
    singleton.define_method(:ransackable_attributes) { |_auth_object = nil| attributes }

    get "/rails_exception_log/logged_exceptions"

    assert_response :success
    assert_select "select[name='q[priority_eq]']", count: 0
    assert_select "th.rn-col-source", text: "Source"
    assert_select "th.rn-col-workflow", count: 0
  ensure
    singleton&.define_method(:ransackable_attributes, original) if original
  end

  test "index with auth block allows access" do
    get "/rails_exception_log/logged_exceptions"
    assert_response :success
  end

  test "index with auth block denies access" do
    RailsExceptionLog.configuration.auth_block = ->(_controller) { false }
    get "/rails_exception_log/logged_exceptions"
    assert_response :forbidden
  end

  test "show returns success" do
    get "/rails_exception_log/logged_exceptions/#{@exception.id}"
    assert_response :success
    assert_select ".rn-tab", text: "Context"
    assert_select "[data-rn-tab-content='diagnostic_context']", text: /request-123/
    assert_select ".rn-meta-value", text: "4.2.1"
    assert_select ".rn-detail-title-row .rn-pill", text: "12 occurrences"
  end

  test "previous and next follow the list order and never point at the current record" do
    older = RailsExceptionLog::LoggedException.create!(exception_class: "OlderError", message: "older", created_at: 2.hours.ago)
    newer = RailsExceptionLog::LoggedException.create!(exception_class: "NewerError", message: "newer", created_at: 1.minute.from_now)

    get "/rails_exception_log/logged_exceptions/#{@exception.id}"
    assert_select ".rn-nav-link[href^='/rails_exception_log/logged_exceptions/#{newer.id}'] .rn-nav-link-title", text: "NewerError"
    assert_select ".rn-nav-link[href^='/rails_exception_log/logged_exceptions/#{older.id}'] .rn-nav-link-title", text: "OlderError"
    assert_select ".rn-nav-link[href^='/rails_exception_log/logged_exceptions/#{@exception.id}']", count: 0

    get "/rails_exception_log/logged_exceptions/#{newer.id}"
    assert_select ".rn-nav-link-label", text: "Previous", count: 0
    assert_select ".rn-nav-link-label", text: "Next"
  end

  test "exception class names are escaped while still wrapping at ::" do
    @exception.update!(exception_class: "Billing::<img src=x onerror=alert(1)>")

    get "/rails_exception_log/logged_exceptions/#{@exception.id}"
    assert_select ".rn-detail-title img", count: 0
    assert_select ".rn-detail-title wbr", count: 1
    assert_includes response.body, "Billing::<wbr>&lt;img src=x onerror=alert(1)&gt;"

    get "/rails_exception_log/logged_exceptions"
    assert_select ".rn-exception-name img", count: 0
  end

  test "show leaves the appended context out of the message and lists request fields" do
    @exception.update!(
      message: "boom\n* Extra Data\n\n{:user_id=>7}",
      request: "* Method: GET\n* URL: http://example.com/orders/7",
      priority: "critical",
      assigned_to: "amina"
    )

    get "/rails_exception_log/logged_exceptions/#{@exception.id}"

    assert_select ".rn-detail-subtitle", text: "boom"
    assert_select ".rn-detail-title-row .rn-pill-danger", text: "Critical"
    assert_select ".rn-detail-title-row .rn-pill-info", text: "@amina"
    assert_select ".rn-kv-row dt", text: "Method"
    assert_select ".rn-kv-row dd", text: "http://example.com/orders/7"

    get "/rails_exception_log/logged_exceptions"
    assert_select ".rn-msg", text: "boom"
    assert_select ".rn-row-badges .rn-pill", text: "Critical"
  end

  test "show as turbo stream" do
    get "/rails_exception_log/logged_exceptions/#{@exception.id}", as: :turbo_stream
    assert_response :success
  end

  test "destroy removes exception" do
    assert_difference "RailsExceptionLog::LoggedException.count", -1 do
      delete "/rails_exception_log/logged_exceptions/#{@exception.id}"
    end
    assert_redirected_to "/rails_exception_log/logged_exceptions"
  end

  test "destroy as turbo stream" do
    assert_difference "RailsExceptionLog::LoggedException.count", -1 do
      delete "/rails_exception_log/logged_exceptions/#{@exception.id}", as: :turbo_stream
    end
    assert_response :success
  end

  test "destroy_all removes filtered exceptions" do
    RailsExceptionLog::LoggedException.create!(
      exception_class: "ArgumentError",
      controller_name: "posts",
      action_name: "index",
      message: "Another error",
      backtrace: "app/test.rb:2",
      request: "GET /posts",
      environment: "Rails: test"
    )

    assert_difference "RailsExceptionLog::LoggedException.count", -2 do
      post "/rails_exception_log/logged_exceptions/destroy_all"
    end
  end

  test "destroy_all with ids removes specific exceptions" do
    RailsExceptionLog::LoggedException.create!(
      exception_class: "ArgumentError",
      controller_name: "posts",
      action_name: "index",
      message: "Another error",
      backtrace: "app/test.rb:2",
      request: "GET /posts",
      environment: "Rails: test"
    )

    assert_difference "RailsExceptionLog::LoggedException.count", -1 do
      post "/rails_exception_log/logged_exceptions/destroy_all", params: { ids: @exception.id.to_s }
    end
  end

  test "clear removes all exceptions" do
    RailsExceptionLog::LoggedException.create!(
      exception_class: "TypeError",
      controller_name: "home",
      action_name: "index",
      message: "Third error",
      backtrace: "app/test.rb:3",
      request: "GET /home",
      environment: "Rails: test"
    )

    assert_difference "RailsExceptionLog::LoggedException.count", -2 do
      post "/rails_exception_log/logged_exceptions/clear"
    end
  end

  test "query filters by message" do
    get "/rails_exception_log/logged_exceptions/query", params: { query: "Test error" }
    assert_response :success
  end

  test "query filters by exception class" do
    get "/rails_exception_log/logged_exceptions/query", params: { exception_names_filter: "RuntimeError" }
    assert_response :success
  end

  test "query filters by date" do
    get "/rails_exception_log/logged_exceptions/query", params: { date_ranges_filter: 7 }
    assert_response :success
  end

  test "query filters by controller action" do
    get "/rails_exception_log/logged_exceptions/query", params: { controller_actions_filter: "users/show" }
    assert_response :success
  end

  test "feed returns RSS" do
    get "/rails_exception_log/logged_exceptions/feed", params: { format: :rss }
    assert_response :success
  end

  test "feed is empty when no exceptions" do
    RailsExceptionLog::LoggedException.delete_all
    get "/rails_exception_log/logged_exceptions/feed", params: { format: :rss }
    assert_response :success
  end
end
