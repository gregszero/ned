# frozen_string_literal: true

require_relative '../test_helper'

class ScheduledTaskTest < Fang::TestCase
  def test_validations
    task = Fang::ScheduledTask.new
    refute task.valid?
    assert task.errors[:title].any?
    assert task.errors[:scheduled_for].any?
  end

  def test_due_when_past_and_pending
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: 1.hour.ago, status: 'pending')
    assert task.due?
  end

  def test_not_due_when_future
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: 1.hour.from_now, status: 'pending')
    refute task.due?
  end

  def test_not_due_when_completed
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: 1.hour.ago, status: 'completed')
    refute task.due?
  end

  def test_mark_running!
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: Time.current, status: 'pending')
    task.mark_running!
    assert task.running?
  end

  def test_mark_completed!
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: Time.current, status: 'running')
    task.mark_completed!('done')
    assert task.completed?
    assert_equal 'done', task.result
  end

  def test_mark_failed!
    task = Fang::ScheduledTask.create!(title: 'Test', scheduled_for: Time.current, status: 'running')
    task.mark_failed!('broken')
    assert task.failed?
    assert_equal 'broken', task.result
  end

  def test_due_scope
    Fang::ScheduledTask.create!(title: 'Due', scheduled_for: 1.hour.ago, status: 'pending')
    Fang::ScheduledTask.create!(title: 'Future', scheduled_for: 1.hour.from_now, status: 'pending')
    Fang::ScheduledTask.create!(title: 'Done', scheduled_for: 1.hour.ago, status: 'completed')

    assert_equal 1, Fang::ScheduledTask.due.count
  end

  def test_default_parameters
    task = Fang::ScheduledTask.new(title: 'Test', scheduled_for: Time.current)
    assert_equal({}, task.parameters)
  end

  def test_recurring?
    task = Fang::ScheduledTask.new(recurring: true, cron_expression: '*/5 * * * *')
    assert task.recurring?

    task2 = Fang::ScheduledTask.new(recurring: false)
    refute task2.recurring?
  end
end
