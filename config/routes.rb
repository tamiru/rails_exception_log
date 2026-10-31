RailsExceptionLog::Engine.routes.draw do
  resources :logged_exceptions do
    collection do
      post :clear
      match :query, via: %i[get post]
      post :destroy_all
      get :feed
    end
    member do
      post :assign, to: "workflow#assign"
      post :set_priority, to: "workflow#set_priority"
      post :snooze, to: "workflow#snooze"
      post :mute, to: "workflow#mute"
      post :unmute, to: "workflow#unmute"
      post :add_comment, to: "workflow#add_comment"
    end
  end

  # Source code viewing
  get "source_code", to: "source_code#show", as: :source_code

  root to: "logged_exceptions#index"
end
