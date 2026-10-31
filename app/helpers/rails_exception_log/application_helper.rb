module RailsExceptionLog
  module ApplicationHelper
    def page_title(text)
      title = [RailsExceptionLog.application_name.presence, text].compact.join(" :: ")
      content_for(:title, title)
    end

    def rails_exception_log_pagy_nav(pagy)
      pagy.series_nav
    end
  end
end
