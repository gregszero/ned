# frozen_string_literal: true

require 'monitor'

module Ai
  module Web
    # In-memory pub/sub for delivering Turbo Streams over SSE.
    # Works because ActiveJob async adapter runs in the same process.
    module TurboBroadcast
      extend MonitorMixin

      @subscribers = Hash.new { |h, k| h[k] = [] }

      class << self
        def subscribe(channel, &block)
          synchronize { @subscribers[channel] << block }
          block
        end

        def unsubscribe(channel, block)
          synchronize { @subscribers[channel].delete(block) }
        end

        def broadcast(channel, html)
          synchronize { @subscribers[channel].dup }.each do |block|
            block.call(html)
          rescue => e
            Ai.logger.error "Broadcast error: #{e.message}"
          end
        end
      end
    end
  end
end
