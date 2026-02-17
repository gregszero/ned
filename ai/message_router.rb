# frozen_string_literal: true

module Ai
  module MessageRouter
    def self.route(message, **)
      Ai.logger.info "Routing message to agent: #{message.content[0..50]}..."
      Jobs::AgentExecutorJob.perform_later(message.id)
    end
  end
end
