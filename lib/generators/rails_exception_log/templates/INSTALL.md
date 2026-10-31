RailsExceptionLog has been installed.

Next steps:

1. Review `config/initializers/rails_exception_log.rb` and configure `auth_block`.
2. Run `bin/rails db:migrate`.
3. Visit `/rails_exception_log` in the host application.

The dashboard denies access until authentication is configured.
The generator captures `StandardError` application failures and deliberately leaves fatal process and VM exceptions to Rails and Ruby.
