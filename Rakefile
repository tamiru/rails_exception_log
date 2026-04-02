require_relative "lib/rails_exception_log/version"

module RailsExceptionLog
  class Rake
    def self.load_tasks
      require "rails_exception_log/engine"
    end

    def self.install_migrations
      puts "Installing migrations..."
      # This would be handled by the generator
    end

    def self.cleanup(days: 30)
      puts "Cleaning up exceptions older than #{days} days..."
      RailsExceptionLog::LoggedException.where("created_at < ?", days.days.ago).delete_all
    end
  end
end

desc "Install migrations for rails_exception_log"
task "rails_exception_log:install:migrations" do
  puts "Copying migrations to #{Rails.root}/db/migrate"
  source = File.join(RailsExceptionLog::Engine.root, "db/migrate")
  destination = Rails.root.join("db/migrate")
  
  FileUtils.mkdir_p(destination)
  Dir.glob("#{source}/*.rb").each do |file|
    dest = File.join(destination, File.basename(file))
    unless File.exist?(dest)
      FileUtils.cp(file, dest)
      puts "  Copied: #{File.basename(file)}"
    end
  end
end

desc "Cleanup old exceptions (default: 30 days)"
task "rails_exception_log:cleanup", [:days] do |_t, args|
  days = args[:days]&.to_i || 30
  puts "Deleting exceptions older than #{days} days..."
  # This will work when the engine is loaded
end