module RailsExceptionLog
  class LoggedException < ::ActiveRecord::Base
    self.table_name = 'rails_exception_log_logged_exceptions'

    enum :status, { open: 0, resolved: 1, reopened: 2, ignored: 3 }, prefix: true
    enum :severity, { info: 0, warning: 1, error: 2, critical: 3 }, prefix: true

    validates :exception_class, presence: true

    scope :recent, -> { order(last_occurred_at: :desc) }
    scope :today, -> { where('created_at >= ?', Date.today) }
    scope :last_days, ->(days) { where('created_at >= ?', days.days.ago) }
    scope :by_class, ->(klass) { where(exception_class: klass) }
    scope :by_controller, ->(controller) { where(controller_name: controller) }
    scope :by_status, ->(status) { where(status: statuses[status]) }
    scope :unresolved, -> { where(status: [statuses[:open], statuses[:reopened]]) }
    scope :high_severity, -> { where('severity >= ?', severities[:error]) }

    def self.filter_by_date(range)
      case range
      when 'today'
        today
      when '7days'
        last_days(7)
      when '30days'
        last_days(30)
      else
        all
      end
    end

    def self.generate_fingerprint(exception, request = nil)
      fingerprint_parts = [
        exception.class.name,
        exception.message.to_s.split("\n").first[0..200],
        request&.path
      ].compact

      Digest::SHA256.hexdigest(fingerprint_parts.join('|'))
    end

    def self.create_or_update_with_fingerprint!(exception, request = nil, user: nil)
      fp = generate_fingerprint(exception, request)
      existing = where(fingerprint: fp, status: [statuses[:open], statuses[:reopened]]).first

      if existing
        updates = {
          occurrence_count: existing.occurrence_count + 1,
          last_occurred_at: Time.current
        }
        updates[:backtrace] = exception.backtrace.join("\n") if exception.backtrace
        existing.update!(updates)
        existing
      else
        create!(
          exception_class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.join("\n"),
          controller_name: request&.controller_name,
          action_name: request&.action_name,
          request_method: request&.method&.to_s,
          request_path: request&.path,
          request_params: request&.params,
          request_headers: request_headers(request),
          session_data: session_data(request),
          environment: Rails.env,
          fingerprint: fp,
          user_id: user&.id,
          user_email: user&.email,
          last_occurred_at: Time.current
        )
      end
    end

    def self.request_headers(request)
      return {} unless request&.headers

      {
        'HTTP_HOST' => request.headers['HTTP_HOST'],
        'HTTP_USER_AGENT' => request.headers['HTTP_USER_AGENT'],
        'REMOTE_ADDR' => request.remote_ip
      }.compact
    end

    def self.session_data(request)
      return {} unless request&.session

      begin
        request.session.to_hash
      rescue StandardError
        {}
      end
    end

    def formatted_backtrace
      return [] unless backtrace

      backtrace.split("\n").reject(&:blank?)
    end

    def request_params_display
      return {} unless request_params

      request_params.with_indifferent_access
    end

    def session_data_display
      return {} unless session_data

      session_data.with_indifferent_access
    end

    def mark_resolved!
      update!(status: :resolved, resolved_at: Time.current)
    end

    def mark_open!
      update!(status: :reopened, resolved_at: nil)
    end

    def add_comment!(comment, author: nil)
      comment_data = {
        body: comment,
        author: author || 'System',
        created_at: Time.current.iso8601
      }

      existing_comments = comments.present? ? JSON.parse(comments) : []
      existing_comments << comment_data
      update!(comments: existing_comments.to_json)
    end

    def reopen_if_needed!
      return unless resolved? && last_occurred_at && last_occurred_at > resolved_at

      update!(status: :reopened, resolved_at: nil)
    end

    def status_label
      case status
      when 'open' then 'Open'
      when 'resolved' then 'Resolved'
      when 'reopened' then 'Reopened'
      when 'ignored' then 'Ignored'
      else 'Unknown'
      end
    end
  end
end
