# Raises from a controller that also records through the concern.
class ConcernFailuresController < ApplicationController
  include RailsExceptionLog::ExceptionLoggable
  rescue_from StandardError, with: :log_exception_handler

  def show
    raise ArgumentError, "concern failure"
  end
end
