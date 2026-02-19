# frozen_string_literal: true

module Fang
  module ComputerUse
    class Agent
      MAX_ITERATIONS = 50

      SYSTEM_PROMPT = <<~PROMPT
        You are a computer use agent. You control a desktop with a browser to complete tasks.
        You can see the screen via screenshots and interact using mouse clicks, keyboard input, and scrolling.
        Be methodical: look at the screen, plan your action, execute it, then verify the result.
        When the task is complete, respond with a text summary of what you accomplished.
      PROMPT

      TOOL_DEFINITION = {
        type: "computer_20251124",
        name: "computer",
        display_width_px: 1024,
        display_height_px: 768
      }.freeze

      def initialize(display_server:, client: nil)
        @display_server = display_server
        @client = client || Clients::AnthropicClient.new
      end

      def execute(task:, &on_event)
        messages = []

        # Take initial screenshot
        initial_screenshot = @display_server.screenshot
        yield({ type: :screenshot, base64: initial_screenshot }) if on_event

        messages << {
          role: "user",
          content: [
            { type: "text", text: task },
            {
              type: "image",
              source: {
                type: "base64",
                media_type: "image/png",
                data: initial_screenshot
              }
            }
          ]
        }

        MAX_ITERATIONS.times do |i|
          Fang.logger.info "CUA iteration #{i + 1}"

          response = @client.create_message(
            model: "claude-sonnet-4-20250514",
            messages: messages,
            tools: [TOOL_DEFINITION],
            system: SYSTEM_PROMPT,
            max_tokens: 4096,
            betas: ["computer-use-2025-01-24"]
          )

          # Parse response content blocks
          content_blocks = response.content || []
          has_tool_use = false
          tool_results = []

          content_blocks.each do |block|
            case block.type
            when "text"
              yield({ type: :text, content: block.text }) if on_event
            when "tool_use"
              has_tool_use = true
              action = block.input&.action || block.input&.dig("action")
              action_params = extract_action_params(block.input)

              yield({ type: :action, action: action, params: action_params }) if on_event

              # Execute the action
              screenshot_data = @display_server.exec_action(action, action_params)

              yield({ type: :screenshot, base64: screenshot_data }) if on_event if screenshot_data

              # Build tool result
              tool_result = {
                type: "tool_result",
                tool_use_id: block.id,
                content: []
              }

              if screenshot_data
                tool_result[:content] << {
                  type: "image",
                  source: {
                    type: "base64",
                    media_type: "image/png",
                    data: screenshot_data
                  }
                }
              end

              tool_results << tool_result
            end
          end

          # Add assistant message
          messages << {
            role: "assistant",
            content: content_blocks.map { |b| block_to_hash(b) }
          }

          # If no tool use, task is complete
          break unless has_tool_use

          # Add tool results
          messages << {
            role: "user",
            content: tool_results
          }
        end
      end

      private

      def extract_action_params(input)
        return {} unless input
        params = {}
        # Handle both OpenStruct and Hash
        input_hash = input.respond_to?(:to_h) ? input.to_h : input
        input_hash.each do |k, v|
          key = k.to_s
          next if key == "action"
          params[key] = v
        end
        params
      end

      def block_to_hash(block)
        case block.type
        when "text"
          { type: "text", text: block.text }
        when "tool_use"
          input = block.input.respond_to?(:to_h) ? block.input.to_h : block.input
          { type: "tool_use", id: block.id, name: block.name, input: input }
        else
          { type: block.type }
        end
      end
    end
  end
end
