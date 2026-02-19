# frozen_string_literal: true

module Fang
  module MessageRouter
    def self.route(message, **)
      Fang.logger.info "Routing message to agent: #{message.content[0..50]}..."
      Jobs::AgentExecutorJob.perform_later(message.id)
    end
  end
end
