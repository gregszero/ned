# frozen_string_literal: true

require_relative 'ai/bootstrap'
require_relative 'web/app'

# Start the scheduler for recurring tasks
Ai::Scheduler.start!

# Freeze the app for better performance
run Ai::Web::App.freeze.app
