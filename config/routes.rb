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
