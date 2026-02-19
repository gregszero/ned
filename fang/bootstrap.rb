# frozen_string_literal: true

require 'bundler/setup'
require 'pathname'
require 'active_record'
require 'logger'

module Fang
  class << self
    attr_accessor :root, :logger

    def env
      ENV['FANG_ENV'] || ENV['RACK_ENV'] || 'development'
    end

    def load!
      @root = Pathname.new(__dir__).parent
      @logger = Logger.new($stdout)
      @logger.level = env == 'production' ? Logger::INFO : Logger::DEBUG

      # Load dotenv for environment variables
      require 'dotenv'
      Dotenv.load("#{root}/.env.#{env}", "#{root}/.env")

      # Load core components
      load_core_components
    end

    private

    def load_core_components
      # Core framework files (order matters)
      require_relative 'application_client'
      require_relative 'database'
      require_relative 'system_profile'
      require_relative 'agent'
      require_relative 'scheduler'
      require_relative 'skill_loader'
      require_relative 'python_runner'
      require_relative 'message_router'
      require_relative 'whatsapp'
      require_relative 'gmail'
      require_relative 'mcp_server'
      require_relative 'event_bus'

      # Load computer use subsystem
      require_relative 'computer_use/display_server'
      require_relative 'computer_use/agent'

      # Load concerns and models
      Dir[root.join('fang/concerns/**/*.rb')].sort.each { |f| require f }
      Dir[root.join('fang/models/**/*.rb')].sort.each { |f| require f }

      # Load API clients
      Dir[root.join('fang/clients/**/*.rb')].sort.each { |f| require f }

      # Load widgets
      require_relative 'widgets/base_widget'
      Dir[root.join('fang/widgets/**/*.rb')].sort.each { |f| require f unless f.include?('base_widget') }

      # Load jobs
      require_relative 'jobs/application_job'
      Dir[root.join('fang/jobs/**/*.rb')].sort.each { |f| require f unless f.include?('application_job') }

      # Configure ActiveJob queue adapter
      require_relative 'queue'

      # Connect to database if configured
      Fang::Database.connect! if Fang::Database.configured?

      # Detect host system capabilities
      Fang::SystemProfile.detect!
    end
  end
end

# Auto-load the framework
Fang.load!
