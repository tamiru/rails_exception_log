module RailsExceptionLog
  module ApplicationHelper
    def exception_status_class(exception)
      case exception.environment
      when 'production' then 'bg-red-100 text-red-800'
      when 'staging' then 'bg-amber-100 text-amber-800'
      else 'bg-slate-100 text-slate-800'
      end
    end

    def exception_status_badge(exception)
      case exception.status.to_s
      when 'open' then 'bg-red-100 text-red-800'
      when 'resolved' then 'bg-green-100 text-green-800'
      when 'reopened' then 'bg-orange-100 text-orange-800'
      when 'ignored' then 'bg-slate-100 text-slate-600'
      else 'bg-slate-100 text-slate-800'
      end
    end

    def severity_badge(severity)
      case severity.to_i
      when 3 then 'bg-red-600 text-white'
      when 2 then 'bg-orange-500 text-white'
      when 1 then 'bg-yellow-500 text-white'
      else 'bg-blue-500 text-white'
      end
    end

    def format_datetime(datetime)
      return '-' unless datetime

      datetime.strftime('%Y-%m-%d %H:%M:%S')
    end

    def format_datetime_relative(datetime)
      return '-' unless datetime

      time_ago_in_words(datetime)
    end

    def request_method_class(method)
      case method&.upcase
      when 'GET' then 'bg-green-100 text-green-800'
      when 'POST' then 'bg-blue-100 text-blue-800'
      when 'PUT', 'PATCH' then 'bg-amber-100 text-amber-800'
      when 'DELETE' then 'bg-red-100 text-red-800'
      else 'bg-slate-100 text-slate-800'
      end
    end

    def truncate_text(text, length: 50)
      return '-' unless text

      text.length > length ? "#{text[0...length]}..." : text
    end
  end
end
