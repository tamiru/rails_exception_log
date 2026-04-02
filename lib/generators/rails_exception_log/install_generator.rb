require 'rails/generators/base'

module RailsExceptionLog
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('install/templates', __dir__)

      class_option :skip_migrations, type: :boolean, default: false,
                                     desc: 'Skip migrations installation'

      def copy_migrations
        return if options[:skip_migrations]

        puts 'Copying migrations...'
        migrations_dir = File.expand_path('db/migrate', destination_root)
        FileUtils.mkdir_p(migrations_dir)

        source_migrations = File.join(__dir__, '../../db/migrate/*.rb')
        Dir.glob(source_migrations).each do |file|
          filename = File.basename(file)
          dest = File.join(migrations_dir, filename)
          if File.exist?(dest)
            puts "  skip   #{filename} (already exists)"
          else
            FileUtils.cp(file, dest)
            puts "  create  #{filename}"
          end
        end
      end

      def add_routes
        route_content = "
# Exception Log Routes
mount RailsExceptionLog::Engine => '/exceptions'
"

        route_file = File.expand_path('config/routes.rb', destination_root)
        return unless File.exist?(route_file)

        existing_content = File.read(route_file)
        return if existing_content.include?('RailsExceptionLog::Engine')

        File.open(route_file, 'a') do |f|
          f.puts route_content
        end
        puts '  route  mount RailsExceptionLog::Engine'
      end

      def show_readme
        readme 'lib/generators/install/templates/README.md' if behavior == :invoke
      end
    end
  end
end
