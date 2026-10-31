Rails.application.routes.draw do
  mount RailsExceptionLog::Engine => "/rails_exception_log"

  get "failures/:kind", to: "failures#show"
  get "concern_failures", to: "concern_failures#show"
end
