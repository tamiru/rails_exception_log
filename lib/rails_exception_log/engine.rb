require 'rails'

module RailsExceptionLog
  class Engine < ::Rails::Engine
    isolate_namespace RailsExceptionLog

    initializer 'rails_exception_log.assets' do |app|
      app.config.assets.paths << root.join('app/assets/stylesheets') if defined?(Sprockets) && app.config.assets

      if defined?(Propshaft)
        app.config.assets.loader = 'bun'
        app.config.assets.build_paths << root.join('app/assets/builds')
      end
    end

    initializer 'rails_exception_log.helpers' do
      ActionView::Base.include RailsExceptionLog::ApplicationHelper
    end

    config.after_initialize do
      RailsExceptionLog.before_log_exception = lambda { |_controller|
        true
      }
    end
  end
end
