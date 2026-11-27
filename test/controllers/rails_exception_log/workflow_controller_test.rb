# frozen_string_literal: true

require "test_helper"

class RailsExceptionLog::WorkflowControllerTest < ActionDispatch::IntegrationTest
  setup do
    RailsExceptionLog.configure { |config| config.auth_block = ->(_controller) { true } }
    RailsExceptionLog::Comment.delete_all
    RailsExceptionLog::LoggedException.delete_all

    @first = RailsExceptionLog::LoggedException.create!(exception_class: "FirstError", message: "one")
    @second = RailsExceptionLog::LoggedException.create!(exception_class: "SecondError", message: "two")
    @untouched = RailsExceptionLog::LoggedException.create!(exception_class: "OtherError", message: "three")
  end

  test "bulk mute mutes only the ticked rows and records who did it" do
    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id, @second.id], bulk_action: "mute" }

    assert_redirected_to "/rails_exception_log/logged_exceptions"
    assert_equal "Muted 2 exceptions.", flash[:notice]
    assert @first.reload.muted?
    assert @second.reload.muted?
    assert_not @untouched.reload.muted?
    assert_equal "status_change", @first.comments.last.comment_type
  end

  test "bulk priority accepts only known levels" do
    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id], bulk_action: "priority", priority: "urgent!!" }
    assert_equal "Choose a priority.", flash[:notice]
    assert_nil @first.reload.priority

    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id], bulk_action: "priority", priority: "high" }
    assert_equal "high", @first.reload.priority
  end

  test "bulk assign needs a name" do
    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id], bulk_action: "assign", assigned_to: "  " }
    assert_equal "Enter who to assign them to.", flash[:notice]

    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id, @second.id], bulk_action: "assign", assigned_to: "amina" }
    assert_equal %w[amina amina], [@first.reload.assigned_to, @second.reload.assigned_to]
  end

  test "bulk delete removes the rows and their comments" do
    @first.add_comment(author: "ops", body: "looking")

    assert_difference -> { RailsExceptionLog::LoggedException.count } => -2,
                      -> { RailsExceptionLog::Comment.count } => -1 do
      post "/rails_exception_log/logged_exceptions/bulk",
           params: { ids: [@first.id, @second.id], bulk_action: "delete" }
    end
    assert_equal "Deleted 2 exceptions.", flash[:notice]
  end

  test "bulk returns to the filtered list it came from, never another host" do
    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id], bulk_action: "mute",
                   return_to: "/rails_exception_log/logged_exceptions?status_filter=active" }
    assert_redirected_to "/rails_exception_log/logged_exceptions?status_filter=active"

    post "/rails_exception_log/logged_exceptions/bulk",
         params: { ids: [@first.id], bulk_action: "mute", return_to: "https://evil.example/x" }
    assert_redirected_to "/rails_exception_log/logged_exceptions"
  end

  test "bulk with nothing ticked changes nothing" do
    post "/rails_exception_log/logged_exceptions/bulk", params: { bulk_action: "delete" }

    assert_equal "Select at least one exception.", flash[:notice]
    assert_equal 3, RailsExceptionLog::LoggedException.count
  end
end
