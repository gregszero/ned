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
          Ai.logger.info "[TurboBroadcast] Subscribed to #{channel} (#{@subscribers[channel].size} subscribers)"
          block
        end

        def unsubscribe(channel, block)
          synchronize { @subscribers[channel].delete(block) }
          Ai.logger.info "[TurboBroadcast] Unsubscribed from #{channel} (#{@subscribers[channel].size} remaining)"
        end

        def broadcast(channel, html)
          subs = synchronize { @subscribers[channel].dup }
          Ai.logger.info "[TurboBroadcast] Broadcasting to #{channel}: #{subs.size} subscribers"
          subs.each do |block|
            block.call(html)
          rescue => e
            Ai.logger.error "Broadcast error: #{e.message}"
          end
        end
      end
    end
  end
end
