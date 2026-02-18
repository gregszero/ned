# frozen_string_literal: true

module Ai
  module Jobs
    class HeartbeatRunnerJob < ApplicationJob
      queue_as :scheduled_tasks

      def perform(heartbeat_id)
        heartbeat = Heartbeat.find(heartbeat_id)

        # Guard: re-check due_now? to prevent double execution
        unless heartbeat.due_now?
          Ai.logger.info "Heartbeat '#{heartbeat.name}' not due, skipping"
          return
        end

        Ai.logger.info "Running heartbeat: #{heartbeat.name} (skill: #{heartbeat.skill_name})"

        # Phase 1: Execute skill (pure Ruby, zero tokens)
        skill = SkillRecord.find_by(name: heartbeat.skill_name)
        unless skill
          heartbeat.record_run!(status: 'error', error: "Skill not found: #{heartbeat.skill_name}")
          broadcast_refresh(heartbeat)
          return
        end

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = skill.load_and_execute
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round

        if heartbeat.result_meaningful?(result)
          # Meaningful data — record success and escalate to AI
          heartbeat.record_run!(status: 'success', result: result, escalated: true, duration_ms: duration_ms)
          broadcast_refresh(heartbeat)

          # Phase 2: Escalate to AI agent
          escalate_to_agent(heartbeat, result)
        else
          # Empty result — record skip, no AI invocation
          heartbeat.record_run!(status: 'skipped', result: result, escalated: false, duration_ms: duration_ms)
          broadcast_refresh(heartbeat)
        end

        # Clear error status if we got here without raising
        heartbeat.update!(status: 'active') if heartbeat.error?

      rescue ActiveRecord::RecordNotFound => e
        Ai.logger.error "Heartbeat not found: #{e.message}"
      rescue => e
        Ai.logger.error "Heartbeat '#{heartbeat&.name}' failed: #{e.message}"
        if heartbeat
          heartbeat.record_run!(status: 'error', error: e.message, duration_ms: nil)
          heartbeat.update!(status: 'error') if heartbeat.error_count >= 3
          broadcast_refresh(heartbeat)
        end
      end

      private

      def escalate_to_agent(heartbeat, result)
        prompt = heartbeat.interpolated_prompt(result)
        return unless prompt.present?

        conversation = find_or_create_conversation(heartbeat)

        message = conversation.add_message(
          role: 'user',
          content: prompt
        )

        AgentExecutorJob.perform_later(message.id)
        Ai.logger.info "Heartbeat '#{heartbeat.name}' escalated to AI (conversation #{conversation.id})"
      end

      def find_or_create_conversation(heartbeat)
        meta = heartbeat.metadata || {}
        conv_id = meta['conversation_id']

        if conv_id
          conversation = Conversation.find_by(id: conv_id)
          return conversation if conversation
        end

        conversation = Conversation.create!(
          title: "Heartbeat: #{heartbeat.name}",
          source: 'heartbeat',
          ai_page_id: heartbeat.ai_page_id
        )

        heartbeat.update!(metadata: meta.merge('conversation_id' => conversation.id))
        conversation
      end

      def broadcast_refresh(heartbeat)
        page = heartbeat.ai_page || AiPage.find_by(slug: 'heartbeats')
        return unless page

        component = page.canvas_components.find_by(component_type: 'heartbeat_monitor')
        return unless component

        widget_class = Widgets::BaseWidget.for_type('heartbeat_monitor')
        return unless widget_class

        widget = widget_class.new(component)
        if widget.refresh_data!
          turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                  "<template>#{widget.render_component_html}</template></turbo-stream>"
          Web::TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
        end
      rescue => e
        Ai.logger.error "Heartbeat broadcast failed: #{e.message}"
      end
    end
  end
end
