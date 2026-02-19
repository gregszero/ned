# frozen_string_literal: true

require_relative '../test_helper'

class ScheduleTaskToolTest < Fang::ToolTestCase
  def test_schedule_with_iso8601
    tool = Fang::Tools::ScheduleTaskTool.new
    future = (Time.current + 3600).iso8601
    result = tool.call(title: 'Future Task', scheduled_for: future)

    assert result[:success]
    assert result[:task_id]

    task = Fang::ScheduledTask.find(result[:task_id])
    assert_equal 'Future Task', task.title
    assert task.pending?
  end

  def test_schedule_relative_time
    tool = Fang::Tools::ScheduleTaskTool.new
    result = tool.call(title: 'Soon', scheduled_for: '5 minutes')

    assert result[:success]
    task = Fang::ScheduledTask.find(result[:task_id])
    assert task.scheduled_for > Time.current
    assert task.scheduled_for < 6.minutes.from_now
  end

  def test_schedule_tomorrow
    tool = Fang::Tools::ScheduleTaskTool.new
    result = tool.call(title: 'Tomorrow', scheduled_for: 'tomorrow')

    assert result[:success]
    task = Fang::ScheduledTask.find(result[:task_id])
    assert task.scheduled_for > Time.current
  end

  def test_invalid_time_format
    tool = Fang::Tools::ScheduleTaskTool.new
    result = tool.call(title: 'Bad Time', scheduled_for: 'not a time')

    refute result[:success]
    assert result[:error].include?('Invalid time format')
  end

  def test_recurring_task
    tool = Fang::Tools::ScheduleTaskTool.new
    result = tool.call(title: 'Every 5 min', scheduled_for: '1 hour', cron: '*/5 * * * *')

    assert result[:success]
    assert result[:recurring]
    assert_equal '*/5 * * * *', result[:cron_expression]
  end

  def test_invalid_cron
    tool = Fang::Tools::ScheduleTaskTool.new
    result = tool.call(title: 'Bad Cron', scheduled_for: '1 hour', cron: 'not cron')

    refute result[:success]
    assert result[:error].include?('Invalid cron')
  end
end
