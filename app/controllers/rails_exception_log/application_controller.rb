module RailsExceptionLog
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :ensure_exception_log_enabled

    private

    def ensure_exception_log_enabled
      return if Rails.env.development? || Rails.env.test?

      return if RailsExceptionLog.before_log_exception.call(self)

      render plain: 'Unauthorized', status: 401
    end
  end
end
