# frozen_string_literal: true

require 'active_record'

module Fang
  class Database
    class << self
      def configured?
        ENV['DATABASE_URL'] || File.exist?("#{Fang.root}/config/database.yml") || File.exist?("#{Fang.root}/storage/data.db")
      end

      def connect!
        config = load_config
        ActiveRecord::Base.establish_connection(config)
        ActiveRecord::Base.logger = Fang.logger

        if config.is_a?(Hash) && config[:adapter] == 'sqlite3'
          ActiveRecord::Base.connection.execute("PRAGMA journal_mode=WAL")
          ActiveRecord::Base.connection.execute("PRAGMA synchronous=NORMAL")
          Fang.logger.info "SQLite WAL mode enabled"
        end

        db_name = config.is_a?(Hash) ? config[:database] : config
        Fang.logger.info "Connected to database: #{db_name}"
      rescue => e
        Fang.logger.error "Failed to connect to database: #{e.message}"
        raise
      end

      def migrate!
        migrations_path = "#{Fang.root}/workspace/migrations"

        unless Dir.exist?(migrations_path)
          Fang.logger.warn "No migrations directory found at #{migrations_path}"
          return
        end

        ActiveRecord::Migration.verbose = true

        # Ensure schema_migrations table exists
        ensure_schema_migrations_table

        # Load and run each migration file
        migration_files = Dir["#{migrations_path}/*.rb"].sort

        migration_files.each do |file|
          version = File.basename(file).match(/^(\d+)/)[1]

          # Skip if already migrated
          next if migrated_versions.include?(version)

          puts "== Migrating: #{File.basename(file)} =="

          # Load and run the migration
          load file
          migration_name = File.basename(file, '.rb').split('_', 2).last.camelize
          migration_class = Object.const_get(migration_name)
          migration_class.new.migrate(:up)

          # Record migration
          record_migration(version)

          puts "== Migrated: #{File.basename(file)} =="
        end
      end

      def reset!
        connection = ActiveRecord::Base.connection

        # Drop all tables
        connection.tables.each do |table|
          next if table == 'schema_migrations' || table == 'ar_internal_metadata'
          connection.drop_table(table, force: :cascade)
        end

        # Re-run migrations
        migrate!
      end

      private

      def ensure_schema_migrations_table
        conn = ActiveRecord::Base.connection
        return if conn.table_exists?(:schema_migrations)

        conn.create_table :schema_migrations, id: false do |t|
          t.string :version, null: false
        end
        conn.add_index :schema_migrations, :version, unique: true
      end

      def migrated_versions
        ActiveRecord::Base.connection.select_values(
          "SELECT version FROM schema_migrations"
        )
      rescue
        []
      end

      def record_migration(version)
        ActiveRecord::Base.connection.execute(
          "INSERT INTO schema_migrations (version) VALUES ('#{version}')"
        )
      end

      def load_config
        if ENV['DATABASE_URL']
          # Use DATABASE_URL if provided (production)
          return ENV['DATABASE_URL']
        end

        # Load from config/database.yml
        config_file = "#{Fang.root}/config/database.yml"

        unless File.exist?(config_file)
          # Default to SQLite in development
          return {
            adapter: 'sqlite3',
            database: "#{Fang.root}/storage/data.db",
            pool: 16,
            timeout: 5000
          }
        end

        require 'yaml'
        require 'erb'

        config = YAML.safe_load(
          ERB.new(File.read(config_file)).result,
          aliases: true
        )

        config[Fang.env] || config[Fang.env.to_sym]
      end
    end
  end
end
