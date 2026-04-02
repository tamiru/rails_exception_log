require_relative 'lib/rails_exception_log/version'

Gem::Specification.new do |spec|
  spec.name = 'rails_exception_log'
  spec.version = RailsExceptionLog::VERSION
  spec.authors = ['Tamiru Hailu
  ']
  spec.email = ['tamiruhailu@gmail.com']
  spec.summary = 'Modern exception logging gem with Tailwind UI for Rails 7 and 8'
  spec.description = 'A beautiful exception logging gem that stores Rails exceptions in a database with a modern Tailwind UI dashboard'
  spec.homepage = 'https://github.com/tamiru/rails_exception_log'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/yourusername/rails_exception_log/issues',
    'changelog_uri' => 'https://github.com/tamiru/rails_exception_log/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://github.com/tamiru/rails_exception_log#readme',
    'homepage_uri' => 'https://github.com/tamiru/rails_exception_log',
    'source_code_uri' => 'https://github.com/tamiru/rails_exception_log'
  }

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'README.md']
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency 'rails', '>= 7.0', '< 9.0'

  spec.add_development_dependency 'mysql2', '>= 0.5'
  spec.add_development_dependency 'pg', '>= 1.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
end
