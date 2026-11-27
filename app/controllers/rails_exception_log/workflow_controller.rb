module RailsExceptionLog
  class WorkflowController < ApplicationController
    helper RailsExceptionLog::LoggedExceptionsHelper
    before_action :find_exception, except: :bulk

    PRIORITIES = %w[critical high medium low].freeze
    BULK_COLUMNS = { "mute" => "muted", "unmute" => "muted", "priority" => "priority",
                     "assign" => "assigned_to", "resolve" => "resolved_at", "reopen" => "resolved_at" }.freeze
    BULK_LIMIT = 500

    # POST /rails_exception_log/logged_exceptions/:id/assign
    def assign
      @exception.assign_to(params[:assigned_to], author: current_author)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Assigned to #{params[:assigned_to]}" }
        format.json { render json: { status: "ok", assigned_to: @exception.assigned_to } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/:id/priority
    def set_priority
      @exception.set_priority(params[:priority], author: current_author)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Priority set to #{params[:priority]}" }
        format.json { render json: { status: "ok", priority: @exception.priority } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/:id/snooze
    def snooze
      duration = parse_duration(params[:duration])
      @exception.snooze(duration, author: current_author)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Snoozed for #{duration.inspect}" }
        format.json { render json: { status: "ok", snoozed_until: @exception.snoozed_until } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/:id/mute
    def mute
      @exception.mute!(author: current_author)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Muted" }
        format.json { render json: { status: "ok", muted: @exception.muted } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/:id/unmute
    def unmute
      @exception.unmute!(author: current_author)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Unmuted" }
        format.json { render json: { status: "ok", muted: @exception.muted } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/:id/resolve
    def resolve
      @exception.resolve!(author: current_author)
      respond_with_workflow_panel("Resolved")
    end

    # POST /rails_exception_log/logged_exceptions/:id/reopen
    def reopen
      @exception.reopen!(author: current_author)
      respond_with_workflow_panel("Reopened")
    end

    # POST /rails_exception_log/logged_exceptions/:id/comment
    def add_comment
      @exception.add_comment(author: current_author, body: params[:body], comment_type: params[:comment_type] || "comment")
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("comments-list", partial: "rails_exception_log/logged_exceptions/comments_list", locals: { exception: @exception }) }
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: "Comment added" }
        format.json { render json: { status: "ok", comments_count: @exception.comments_count } }
      end
    end

    # POST /rails_exception_log/logged_exceptions/bulk
    # Applies one workflow action to the rows ticked in the list, record by
    # record, so each one gets the same audit comment as a single change.
    def bulk
      exceptions = LoggedException.where(id: bulk_ids)
      notice = if exceptions.none?
        "Select at least one exception."
      else
        apply_bulk_action(exceptions)
      end

      redirect_to bulk_return_path, notice: notice, status: :see_other
    end

    private

    # Resolve and reopen change the header badges as well as the panel, so
    # their turbo stream replaces both.
    def respond_with_workflow_panel(notice)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace("workflow-panel", partial: "rails_exception_log/logged_exceptions/workflow_panel",
                                                   locals: { exception: @exception }),
            turbo_stream.update("rn-detail-badges", helpers.status_badges_for(@exception)),
            turbo_stream.replace("rn-resolution-button",
                                 partial: "rails_exception_log/logged_exceptions/resolution_button",
                                 locals: { exception: @exception })
          ]
        end
        format.html { redirect_back fallback_location: logged_exception_path(@exception), notice: notice }
        format.json { render json: { status: "ok", resolved: @exception.resolved? } }
      end
    end

    def apply_bulk_action(exceptions)
      count = exceptions.size
      label = "#{count} #{'exception'.pluralize(count)}"
      column = BULK_COLUMNS[params[:bulk_action]]
      if column && LoggedException.column_names.exclude?(column)
        return "This action needs the #{column} column; run bin/rails generate rails_exception_log:install."
      end

      case params[:bulk_action]
      when "delete"
        exceptions.destroy_all
        "Deleted #{label}."
      when "mute"
        each_in_transaction(exceptions) { |exception| exception.mute!(author: current_author) }
        "Muted #{label}."
      when "unmute"
        each_in_transaction(exceptions) { |exception| exception.unmute!(author: current_author) }
        "Unmuted #{label}."
      when "resolve"
        each_in_transaction(exceptions) { |exception| exception.resolve!(author: current_author) }
        "Resolved #{label}."
      when "reopen"
        each_in_transaction(exceptions) { |exception| exception.reopen!(author: current_author) }
        "Reopened #{label}."
      when "priority"
        return "Choose a priority." unless PRIORITIES.include?(params[:priority])

        each_in_transaction(exceptions) do |exception|
          exception.set_priority(params[:priority], author: current_author)
        end
        "Set #{label} to #{params[:priority]} priority."
      when "assign"
        assignee = params[:assigned_to].to_s.strip.first(100)
        return "Enter who to assign them to." if assignee.blank?

        each_in_transaction(exceptions) do |exception|
          exception.assign_to(assignee, author: current_author)
        end
        "Assigned #{label} to #{assignee}."
      else
        "Choose an action."
      end
    end

    # Bulk updates are done one record at a time inside a transaction, so a
    # failure leaves every selected row as it was.
    def each_in_transaction(exceptions, &block)
      LoggedException.transaction { exceptions.each(&block) }
    end

    def bulk_ids
      Array(params[:ids]).map(&:to_s).reject(&:blank?).uniq.first(BULK_LIMIT)
    end

    # Back to the list the selection was made in, filters included. Only a
    # path inside this engine's list is accepted, never another host.
    def bulk_return_path
      list_path = logged_exceptions_path
      return_to = params[:return_to].to_s
      return list_path unless return_to.start_with?(list_path) && !return_to.start_with?("//")

      return_to
    end

    def find_exception
      @exception = RailsExceptionLog::LoggedException.find(params[:id])
    end

    def current_author
      # Try to get current user from the host app's auth system
      if respond_to?(:current_user, true) && current_user
        current_user.respond_to?(:email) ? current_user.email : current_user.to_s
      elsif current_user_block
        current_user_block.call(self)
      else
        "anonymous"
      end
    end

    # The configuration has no current_user_block setting, so reading it
    # directly raised NoMethodError on every workflow action in apps without
    # current_user. It is honoured if a host app defines one.
    def current_user_block
      config = RailsExceptionLog.configuration
      config.current_user_block if config.respond_to?(:current_user_block)
    end

    def parse_duration(str)
      case str.to_s
      when /(\d+)\s*hour/
        $1.to_i.hours
      when /(\d+)\s*day/
        $1.to_i.days
      when /(\d+)\s*week/
        $1.to_i.weeks
      else
        24.hours # default: 1 day
      end
    end
  end
end
