RailsExceptionLog::Engine.routes.draw do
  get '/', to: 'logged_exceptions#index', as: :railsexceptionlog_exceptions
  get '/:id', to: 'logged_exceptions#show', as: :railsexceptionlog_exception
  delete '/:id', to: 'logged_exceptions#destroy'
  delete '/', to: 'logged_exceptions#destroy_all'
  get '/export', to: 'logged_exceptions#export'

  post '/:id/resolve', to: 'logged_exceptions#resolve', as: :resolve_railsexceptionlog_exception
  post '/:id/reopen', to: 'logged_exceptions#reopen', as: :reopen_railsexceptionlog_exception
  post '/:id/ignore', to: 'logged_exceptions#ignore', as: :ignore_railsexceptionlog_exception
  post '/:id/add_comment', to: 'logged_exceptions#add_comment',
                           as: :add_comment_railsexceptionlog_exception
end
