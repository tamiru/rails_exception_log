module RailsExceptionLog
  class ApplicationController < ActionController::Base
    include Pagy::Method
    protect_from_forgery with: :exception
    before_action :rails_exception_log_require_auth!

    private

    def rails_exception_log_pagy(collection, **options)
      limit = options.delete(:limit) || RailsExceptionLog.configuration.per_page || 30
      pagy(:offset, collection, limit: limit, **options)
    end

    def rails_exception_log_require_auth!
      auth_block = RailsExceptionLog.configuration.auth_block
      return if auth_block&.call(self)

      head :forbidden
    rescue StandardError => error
      Rails.logger.error("[RailsExceptionLog] Authentication error: #{error.class}: #{error.message}")
      head :forbidden
    end
  end
end
