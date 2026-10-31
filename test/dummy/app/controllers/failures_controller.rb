# Raises without including RailsExceptionLog::ExceptionLoggable, so only the
# middleware can record these.
class FailuresController < ApplicationController
  def show
    raise ActiveRecord::RecordNotFound, "missing record" if params[:kind] == "not_found"

    raise ArgumentError, "dummy failure"
  end
end
