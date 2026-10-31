RailsExceptionLog is installed (or updated).

Next steps:

  1. bin/rails db:migrate
  2. Set config.auth_block in config/initializers/rails_exception_log.rb
     (the dashboard denies everyone until you do).
  3. bin/rails rails_exception_log:doctor   # checks the setup, tells you what to fix
  4. bin/rails rails_exception_log:test     # records a sample exception
  5. Restart the app server and open /rails_exception_log

Exceptions from requests, jobs, rake tasks, and rails runner are recorded
automatically. Nothing needs to be added to your controllers.

To update later: bundle update rails_exception_log, then run this generator
again (it only adds what is missing) and repeat steps 1, 3, and 5.
