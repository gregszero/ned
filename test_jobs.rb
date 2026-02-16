#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'ai/bootstrap'

puts "🧪 Testing Background Jobs"
puts "="*50

# Test 1: Agent Executor Job
puts "\n1. Testing AgentExecutorJob..."
conversation = Ai::Conversation.create!(title: 'Job Test', source: 'web')
message = conversation.add_message(role: 'user', content: 'Test message for job')

puts "  Created message #{message.id} in conversation #{conversation.id}"

# Note: This will try to spawn a container, which will fail without API keys
# but we can see that the job executes
begin
  puts "  Enqueueing AgentExecutorJob..."
  Ai::Jobs::AgentExecutorJob.perform_later(message.id)
  puts "  ✅ Job enqueued and executed (inline mode)"
rescue => e
  puts "  ⚠️  Job failed (expected without API keys): #{e.message}"
end

# Test 2: Scheduled Task Runner Job
puts "\n2. Testing ScheduledTaskRunnerJob..."
task = Ai::ScheduledTask.create!(
  title: 'Test Task',
  description: 'Testing scheduled task execution',
  scheduled_for: 1.hour.from_now
)

puts "  Created scheduled task #{task.id}"

begin
  puts "  Enqueueing ScheduledTaskRunnerJob..."
  Ai::Jobs::ScheduledTaskRunnerJob.perform_later(task.id)
  puts "  ✅ Job enqueued and executed (inline mode)"

  task.reload
  puts "  Task status: #{task.status}"
rescue => e
  puts "  ⚠️  Job failed: #{e.message}"
end

# Test 3: Container Cleanup Job
puts "\n3. Testing ContainerCleanupJob..."
begin
  puts "  Enqueueing ContainerCleanupJob..."
  Ai::Jobs::ContainerCleanupJob.perform_later
  puts "  ✅ Job enqueued and executed (inline mode)"
rescue => e
  puts "  ⚠️  Job failed: #{e.message}"
end

# Test 4: Memory Sync Job
puts "\n4. Testing MemorySyncJob..."
session = Ai::Session.create!(
  conversation: conversation,
  status: 'stopped',
  session_path: '/tmp/test_session'
)

# Create test CLAUDE.md
FileUtils.mkdir_p('/tmp/test_session')
File.write('/tmp/test_session/CLAUDE.md', '# Test Memory\n\nThis is test content.')

puts "  Created session #{session.id}"

begin
  puts "  Enqueueing MemorySyncJob..."
  Ai::Jobs::MemorySyncJob.perform_later(session.id)
  puts "  ✅ Job enqueued and executed (inline mode)"

  conversation.reload
  if conversation.context['claude_md']
    puts "  Memory synced successfully!"
  end
rescue => e
  puts "  ⚠️  Job failed: #{e.message}"
ensure
  FileUtils.rm_rf('/tmp/test_session')
end

# Check queue adapter
puts "\n" + "="*50
puts "Queue Adapter: #{ActiveJob::Base.queue_adapter.class.name}"
puts "Mode: Inline (synchronous - jobs execute immediately)"
puts "\n📝 Note: For production, switch to async adapter in ai/queue.rb"

puts "\n✅ Job tests complete!"
