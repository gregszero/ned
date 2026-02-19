# frozen_string_literal: true

module Ai
  class Heartbeat < ActiveRecord::Base
    self.table_name = 'heartbeats'

    include HasStatus
    statuses :active, :paused, :error

    has_many :heartbeat_runs, dependent: :destroy
    belongs_to :ai_page, optional: true

    validates :name, presence: true, uniqueness: true
    validates :skill_name, presence: true
    validates :frequency, presence: true, numericality: { greater_than: 0 }

    scope :enabled, -> { where(enabled: true) }
    scope :due, -> { enabled.where(status: 'active').where('last_run_at IS NULL OR last_run_at <= ?', Time.current) }

    def due_now?
      return false unless enabled? && active?

      last_run_at.nil? || (Time.current - last_run_at) >= frequency
    end

    def result_meaningful?(result)
      return false if result.nil?
      return false if result == false
      return false if result.respond_to?(:empty?) && result.empty?

      true
    end

    def interpolated_prompt(result)
      return nil unless prompt_template.present?

      prompt_template
        .gsub('{{result}}', result.to_s)
        .gsub('{{skill_name}}', skill_name.to_s)
        .gsub('{{name}}', name.to_s)
    end

    def record_run!(status:, result: nil, error: nil, escalated: false, duration_ms: nil)
      heartbeat_runs.create!(
        status: status,
        result: result.is_a?(String) ? result : result&.to_json,
        error_message: error,
        escalated: escalated,
        duration_ms: duration_ms,
        ran_at: Time.current
      )

      updates = { last_run_at: Time.current, run_count: run_count + 1 }
      updates[:error_count] = error_count + 1 if status.to_s == 'error'
      update!(**updates)
    end

    def frequency_label
      case frequency
      when 0..59 then "#{frequency}s"
      when 60..3599 then "#{frequency / 60}m"
      else "#{frequency / 3600}h"
      end
    end

    def recent_runs(limit = 30)
      heartbeat_runs.order(ran_at: :desc).limit(limit)
    end
  end
end
