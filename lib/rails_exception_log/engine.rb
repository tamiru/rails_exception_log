require 'rails'

module RailsExceptionLog
  class Engine < ::Rails::Engine
    isolate_namespace RailsExceptionLog

    config.eager_load_paths << root.join('app/helpers')

    initializer 'rails_exception_log.assets' do |app|
      app.config.assets.paths << root.join('app/assets/stylesheets') if defined?(Sprockets) && app.config.assets
    end

    initializer 'rails_exception_log.helpers' do
      ActionView::Base.include RailsExceptionLog::ApplicationHelper
    rescue NameError, LoadError
      # Helper may not be available
    end

    config.after_initialize do
      RailsExceptionLog.before_log_exception = lambda { |_controller|
        true
      }
    end
  end
end
