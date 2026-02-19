# frozen_string_literal: true

require_relative 'fang/bootstrap'

namespace :db do
  desc "Run database migrations"
  task :migrate do
    Fang::Database.migrate!
    puts "✅ Migrations complete"
  end

  desc "Rollback database migration"
  task :rollback do
    migrations_path = "#{Fang.root}/workspace/migrations"
    ActiveRecord::MigrationContext.new(migrations_path, ActiveRecord::SchemaMigration).rollback
    puts "✅ Rolled back last migration"
  end

  desc "Reset database (drop all tables and re-migrate)"
  task :reset do
    Fang::Database.reset!
    puts "✅ Database reset complete"
  end

  desc "Create database"
  task :create do
    config = Fang::Database.send(:load_config)

    if config.is_a?(String)
      puts "Using DATABASE_URL, database should already exist"
      return
    end

    adapter = config[:adapter]

    case adapter
    when 'sqlite3'
      FileUtils.mkdir_p(File.dirname(config[:database]))
      FileUtils.touch(config[:database])
      puts "✅ Created SQLite database at #{config[:database]}"
    when 'postgresql'
      # Use postgres database to create the target database
      require 'pg'
      conn = PG.connect(
        host: config[:host] || 'localhost',
        port: config[:port] || 5432,
        user: config[:username] || ENV['USER'],
        password: config[:password],
        dbname: 'postgres'
      )

      conn.exec("CREATE DATABASE #{config[:database]}")
      puts "✅ Created PostgreSQL database: #{config[:database]}"
      conn.close
    else
      puts "❌ Unsupported adapter: #{adapter}"
    end
  rescue PG::DuplicateDatabase
    puts "Database already exists"
  end

  desc "Drop database"
  task :drop do
    config = Fang::Database.send(:load_config)

    if config.is_a?(String)
      puts "Using DATABASE_URL, cannot drop database"
      return
    end

    adapter = config[:adapter]

    case adapter
    when 'sqlite3'
      File.delete(config[:database]) if File.exist?(config[:database])
      puts "✅ Dropped SQLite database"
    when 'postgresql'
      require 'pg'
      conn = PG.connect(
        host: config[:host] || 'localhost',
        port: config[:port] || 5432,
        user: config[:username] || ENV['USER'],
        password: config[:password],
        dbname: 'postgres'
      )

      conn.exec("DROP DATABASE IF EXISTS #{config[:database]}")
      puts "✅ Dropped PostgreSQL database"
      conn.close
    end
  end

  desc "Load seed data"
  task :seed do
    seed_file = "#{Fang.root}/workspace/seeds.rb"
    if File.exist?(seed_file)
      load seed_file
      puts "✅ Seed data loaded"
    else
      puts "No seed file found at #{seed_file}"
    end
  end

  desc "Setup database (create, migrate, seed)"
  task :setup => [:create, :migrate, :seed]
end

namespace :skills do
  desc "List all available skills"
  task :list do
    Fang::SkillLoader.load_all
    skills = Fang::SkillLoader.available_skills

    if skills.empty?
      puts "No skills found in skills/ directory"
    else
      puts "Available skills:"
      skills.each do |skill_name|
        info = Fang::SkillLoader.skill_info(skill_name)
        puts "  - #{skill_name}: #{info[:description]}"
      end
    end
  end

  desc "Reload all skills"
  task :reload do
    Fang::SkillLoader.reload!
    puts "✅ Skills reloaded"
  end
end

namespace :container do
  desc "Build agent container image"
  task :build do
    sh "docker build -f container/Dockerfile -t openfang-agent ."
    puts "✅ Container image built: openfang-agent"
  end

  desc "Cleanup old containers and sessions"
  task :cleanup do
    Fang::Container.cleanup_old_sessions
    puts "✅ Cleaned up old sessions"
  end
end

task default: ['db:migrate']
