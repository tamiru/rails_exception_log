Rails.application.routes.draw do
  mount RailsExceptionLog::Engine => "/rails_exception_log"
end
