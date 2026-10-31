require_relative "lib/rails_exception_log/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_exception_log"
  spec.version     = RailsExceptionLog::VERSION
  spec.authors     = ["Tamiru Hailu"]
  spec.email       = ["tamiruhailu@gmail.com"]
  spec.homepage    = "https://github.com/tamiru/rails_exception_log"
  spec.summary     = "Exception logging and triage dashboard for Rails applications"
  spec.description = "RailsExceptionLog captures exceptions from your Rails application into your database and gives you a dashboard to search, triage, and resolve them: cause chains, breadcrumbs, inline source with git blame, assignment/priority/snooze/mute workflow, comments, storm protection, and webhook/Telegram notifications. Built with Hotwire and Stimulus."
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.license     = "MIT"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/tamiru/rails_exception_log/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/tamiru/rails_exception_log/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/tamiru/rails_exception_log/issues"
  spec.metadata["funding_uri"] = "https://github.com/sponsors/tamiru"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "CHANGELOG.md", "SECURITY.md", "THIRD_PARTY_NOTICES.md", "MIT-LICENSE", "Rakefile", "README.md", "rails_exception_log.gemspec"]
      .reject { |file| file.match?(%r{(?:^|/)(?:\.idea|log|tmp|storage|pkg)(?:/|$)|\.(?:gem|sqlite3|log)\z|Zone\.Identifier\z}) }
  end

  spec.required_ruby_version = ">= 3.2.0"

  spec.add_dependency "rails", "~> 8.0", ">= 8.0.0"
  spec.add_dependency "stimulus-rails", "~> 1.3"
  spec.add_dependency "turbo-rails", "~> 2.0"
  spec.add_dependency "pagy", ">= 43.0"

  spec.add_dependency "ransack", "~> 4.4", ">= 4.4.3"

end
