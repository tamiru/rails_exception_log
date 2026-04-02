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

RailsExceptionLog::Engine.routes.draw do
  get '/exceptions', to: 'logged_exceptions#index', as: :railsexceptionlog_exceptions
  get '/exceptions/:id', to: 'logged_exceptions#show', as: :railsexceptionlog_exception
  delete '/exceptions/:id', to: 'logged_exceptions#destroy'
  delete '/exceptions', to: 'logged_exceptions#destroy_all'
  get '/exceptions/export', to: 'logged_exceptions#export'

  post '/exceptions/:id/resolve', to: 'logged_exceptions#resolve', as: :resolve_railsexceptionlog_exception
  post '/exceptions/:id/reopen', to: 'logged_exceptions#reopen', as: :reopen_railsexceptionlog_exception
  post '/exceptions/:id/ignore', to: 'logged_exceptions#ignore', as: :ignore_railsexceptionlog_exception
  post '/exceptions/:id/add_comment', to: 'logged_exceptions#add_comment',
                                      as: :add_comment_railsexceptionlog_exception
end
