# frozen_string_literal: true

module Ai
  class WorkflowStep < ActiveRecord::Base
    self.table_name = 'workflow_steps'

    # Associations
    belongs_to :workflow

    # Validations
    validates :position, presence: true
    validates :step_type, presence: true, inclusion: { in: %w[skill prompt condition wait notify] }
    validates :status, inclusion: { in: %w[pending running completed failed skipped] }

    def parsed_config
      return {} if config.blank?
      JSON.parse(config)
    rescue JSON::ParserError
      {}
    end

    def execute!(workflow_context)
      cfg = parsed_config

      case step_type
      when 'skill'
        params = interpolate_params(cfg['parameters'] || {}, workflow_context)
        skill = SkillRecord.find_by!(name: cfg['skill_name'])
        skill.load_and_execute(**params.symbolize_keys)
      when 'prompt'
        conversation = workflow.ensure_conversation!
        prompt = interpolate_string(cfg['prompt'], workflow_context)
        message = conversation.add_message(role: 'user', content: prompt)
        Jobs::AgentExecutorJob.perform_later(message.id)
        { conversation_id: conversation.id, message_id: message.id, status: 'enqueued' }
      when 'condition'
        expression = cfg['expression']
        result = eval_condition(expression, workflow_context)
        unless result
          update!(status: 'skipped')
          # Skip to named step or just continue
          if cfg['skip_to']
            target = workflow.workflow_steps.find_by(name: cfg['skip_to'])
            workflow.update!(current_step_index: target.position) if target
          end
        end
        { result: result }
      when 'wait'
        duration = parse_duration(cfg['duration'])
        if duration
          task = ScheduledTask.create!(
            title: "Resume workflow: #{workflow.name}",
            scheduled_for: duration.from_now,
            description: "workflow_resume:#{workflow.id}"
          )
          workflow.pause!
          { scheduled_task_id: task.id, resumes_at: duration.from_now.iso8601 }
        else
          { error: 'Invalid duration' }
        end
      when 'notify'
        notification = Notification.create!(
          title: interpolate_string(cfg['title'] || workflow.name, workflow_context),
          body: interpolate_string(cfg['body'] || '', workflow_context),
          kind: cfg['kind'] || 'info'
        )
        notification.broadcast!
        { notification_id: notification.id }
      end
    end

    private

    def interpolate_string(str, context)
      return str unless str.is_a?(String)
      str.gsub(/\{\{context(?:\.(\w+))?\}\}/) do
        if $1
          context[$1].to_s
        else
          context.to_json
        end
      end
    end

    def interpolate_params(params, context)
      params.transform_values do |v|
        v.is_a?(String) ? interpolate_string(v, context) : v
      end
    end

    def eval_condition(expression, context)
      # Safe evaluation: only allow simple context lookups
      expression.match?(/\Acontext\[/) ? eval(expression) : false
    rescue
      false
    end

    def parse_duration(str)
      return nil unless str
      case str
      when /^(\d+)\s*seconds?$/ then $1.to_i.seconds
      when /^(\d+)\s*minutes?$/ then $1.to_i.minutes
      when /^(\d+)\s*hours?$/ then $1.to_i.hours
      when /^(\d+)\s*days?$/ then $1.to_i.days
      end
    end
  end
end
