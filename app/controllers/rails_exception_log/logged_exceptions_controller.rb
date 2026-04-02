require 'csv'

module RailsExceptionLog
  class LoggedExceptionsController < ApplicationController
    before_action :load_exception, only: %i[show destroy resolve reopen ignore add_comment]

    def index
      @exceptions = filtered_exceptions
                    .select(:id, :exception_class, :message, :controller_name,
                            :action_name, :request_method, :request_path,
                            :environment, :created_at, :status, :occurrence_count,
                            :last_occurred_at, :resolved_at)
                    .order(last_occurred_at: :desc)
                    .page(params[:page])

      @exception_classes = RailsExceptionLog::LoggedException
                           .select(:exception_class)
                           .distinct
                           .pluck(:exception_class)
                           .sort

      @controllers = RailsExceptionLog::LoggedException
                     .select(:controller_name)
                     .distinct
                     .pluck(:controller_name)
                     .compact
                     .sort

      @status_counts = {
        open: RailsExceptionLog::LoggedException.status_open.count,
        resolved: RailsExceptionLog::LoggedException.status_resolved.count,
        reopened: RailsExceptionLog::LoggedException.status_reopened.count,
        ignored: RailsExceptionLog::LoggedException.status_ignored.count
      }

      @stats = {
        total: RailsExceptionLog::LoggedException.count,
        unresolved: RailsExceptionLog::LoggedException.unresolved.count,
        last_24h: RailsExceptionLog::LoggedException.where('created_at >= ?', 24.hours.ago).count
      }

      respond_to do |format|
        format.html
        format.json { render json: @exceptions }
      end
    end

    def show
      @exception_data = @exception.request_params_display
      @session_data = @exception.session_data_display
      @headers = @exception.request_headers || {}
      @comments = @exception.comments.present? ? JSON.parse(@exception.comments) : []
    end

    def destroy
      @exception.destroy
      redirect_to railsexceptionlog_exceptions_path,
                  notice: 'Exception deleted successfully'
    end

    def resolve
      @exception.mark_resolved!
      redirect_to railsexceptionlog_exception_path(@exception),
                  notice: 'Exception marked as resolved'
    end

    def reopen
      @exception.mark_open!
      redirect_to railsexceptionlog_exception_path(@exception),
                  notice: 'Exception reopened'
    end

    def ignore
      @exception.update!(status: :ignored)
      redirect_to railsexceptionlog_exception_path(@exception),
                  notice: 'Exception ignored'
    end

    def add_comment
      @exception.add_comment!(params[:comment], author: current_user_email)
      redirect_to railsexceptionlog_exception_path(@exception),
                  notice: 'Comment added'
    end

    def destroy_all
      if params[:status].present?
        filtered_exceptions.destroy_all
      else
        RailsExceptionLog::LoggedException.delete_all
      end
      redirect_to railsexceptionlog_exceptions_path,
                  notice: 'Exceptions cleared'
    end

    def export
      @exceptions = filtered_exceptions.order(last_occurred_at: :desc)
      respond_to do |format|
        format.csv { send_data export_to_csv(@exceptions), filename: "exceptions-#{Date.today}.csv" }
        format.json { render json: @exceptions }
      end
    end

    private

    def load_exception
      @exception = RailsExceptionLog::LoggedException.find(params[:id])
    end

    def filtered_exceptions
      exceptions = RailsExceptionLog::LoggedException.all

      exceptions = exceptions.filter_by_date(params[:date_range]) if params[:date_range].present?

      exceptions = exceptions.by_class(params[:exception_class]) if params[:exception_class].present?

      exceptions = exceptions.by_controller(params[:controller]) if params[:controller].present?

      exceptions = exceptions.by_status(params[:status]) if params[:status].present?

      if params[:search].present?
        search_term = "%#{params[:search]}%"
        exceptions = exceptions.where(
          'exception_class LIKE ? OR message LIKE ?',
          search_term, search_term
        )
      end

      exceptions
    end

    def export_to_csv(exceptions)
      CSV.generate(headers: true) do |csv|
        csv << ['ID', 'Exception Class', 'Message', 'Controller', 'Action', 'Path', 'Method', 'Environment', 'Status',
                'Occurrences', 'Created At']
        exceptions.each do |exc|
          csv << [
            exc.id,
            exc.exception_class,
            exc.message,
            exc.controller_name,
            exc.action_name,
            exc.request_path,
            exc.request_method,
            exc.environment,
            exc.status_label,
            exc.occurrence_count,
            exc.created_at
          ]
        end
      end
    end

    def current_user_email
      # Override this method to return the current user's email
      'anonymous'
    end
  end
end
