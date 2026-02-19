# Create Skills

Guide for creating Ruby skills that extend OpenFang functionality.

## What this does

Explains how to create Ruby skill classes that:
- Execute custom logic
- Are called via MCP `run_skill` tool
- Get tracked in the database
- Can be scheduled for future execution

## When to use

Use this skill when you want to:
- Add new functionality to OpenFang
- Create reusable Ruby code
- Build skills AI can execute
- Extend framework capabilities

## What are Skills?

Skills are Ruby classes that inherit from `Fang::Skill` and provide specific functionality:

- **Email sender** - Send emails via SMTP
- **Data processor** - Process CSV/JSON data
- **API client** - Call external APIs
- **Report generator** - Generate reports
- **Task automator** - Automate workflows

## Skill Structure

Basic skill template:

```ruby
# skills/my_skill.rb

class MySkill < Fang::Skill
  description "Brief description of what this skill does"

  # Define parameters
  param :name, :string, required: true, description: "User name"
  param :age, :integer, required: false, description: "User age"

  def call(name:, age: nil)
    # Implementation here
    result = "Hello, #{name}!"
    result += " You are #{age} years old." if age

    # Use built-in helpers
    send_message(result)

    # Return result
    { success: true, message: result }
  end
end
```

## Creating a Skill

### Step 1: Create File

Create file in `skills/` directory:

```bash
touch skills/send_email.rb
```

### Step 2: Define Class

```ruby
# skills/send_email.rb

class SendEmail < Fang::Skill
  description "Send email via SMTP"

  param :to, :string, required: true, description: "Recipient email"
  param :subject, :string, required: true, description: "Email subject"
  param :body, :string, required: true, description: "Email body"

  def call(to:, subject:, body:)
    # Implementation
    require 'net/smtp'

    message = <<~EMAIL
      From: #{ENV['SMTP_FROM']}
      To: #{to}
      Subject: #{subject}

      #{body}
    EMAIL

    Net::SMTP.start(ENV['SMTP_HOST'], ENV['SMTP_PORT']) do |smtp|
      smtp.send_message(
        message,
        ENV['SMTP_FROM'],
        to
      )
    end

    { success: true, recipient: to }
  rescue => e
    { success: false, error: e.message }
  end
end
```

### Step 3: Register in Database

```ruby
# Via console
./openfang.rb console

> Fang::SkillRecord.create!(
  name: 'send_email',
  description: 'Send email via SMTP',
  file_path: 'skills/send_email.rb',
  class_name: 'SendEmail'
)
```

### Step 4: Test Skill

```ruby
# Via console
> Fang::SkillLoader.run('send_email',
    to: 'user@example.com',
    subject: 'Test',
    body: 'Hello!'
  )
```

Or via MCP tool:
```ruby
# AI calls run_skill tool with:
{
  "skill_name": "send_email",
  "parameters": {
    "to": "user@example.com",
    "subject": "Test",
    "body": "Hello!"
  }
}
```

## Skill Components

### Description

Brief description for AI:

```ruby
description "Send email via SMTP to specified recipient"
```

### Parameters

Define what the skill accepts:

```ruby
# String parameter
param :email, :string, required: true, description: "Email address"

# Integer parameter
param :count, :integer, required: false, description: "Number of items"

# Boolean parameter
param :active, :boolean, required: false, description: "Active status"

# Array parameter
param :tags, :array, required: false, description: "List of tags"

# Hash parameter
param :config, :hash, required: false, description: "Configuration options"
```

### Call Method

Main execution method:

```ruby
def call(**params)
  # Access parameters
  email = params[:email]
  count = params[:count] || 10

  # Do work
  result = perform_action(email, count)

  # Return hash
  {
    success: true,
    result: result
  }
end
```

## Built-in Helpers

Skills have access to helper methods:

### send_message

Send message back to user:

```ruby
def call(**params)
  send_message("Processing started...")

  result = do_work

  send_message("Done! Result: #{result}")

  { success: true }
end
```

### schedule_task

Schedule future execution:

```ruby
def call(**params)
  schedule_task(
    title: "Follow-up email",
    scheduled_for: 1.day.from_now,
    skill_name: "send_email",
    parameters: { to: params[:email] }
  )

  { success: true, scheduled: true }
end
```

### run_query

Execute database queries:

```ruby
def call(**params)
  results = run_query("SELECT * FROM conversations LIMIT 10")

  { success: true, count: results.count }
end
```

## Lifecycle Hooks

Override hooks for custom behavior:

```ruby
class MySkill < Fang::Skill
  # Run before call
  def before_call
    Fang.logger.info "Starting #{self.class.name}"
  end

  # Run after call
  def after_call
    Fang.logger.info "Completed #{self.class.name}"
  end

  # Handle errors
  def on_error(error)
    Fang.logger.error "Skill failed: #{error.message}"
    send_message("Error: #{error.message}")
  end

  def call(**params)
    # Main logic
  end
end
```

## Example Skills

### Blog Post Creator

```ruby
class CreateBlogPost < Fang::Skill
  description "Create a new blog post with title and content"

  param :title, :string, required: true
  param :content, :string, required: true
  param :tags, :array, required: false

  def call(title:, content:, tags: [])
    post = Page.create!(
      title: title,
      content: content,
      status: 'published',
      published_at: Time.current,
      metadata: { tags: tags }
    )

    send_message("Blog post created: #{post.title}")

    {
      success: true,
      post_id: post.id,
      url: "/pages/#{post.slug}"
    }
  end
end
```

### Weather Fetcher

```ruby
class FetchWeather < Fang::Skill
  description "Fetch weather for a city using OpenWeather API"

  param :city, :string, required: true
  param :units, :string, required: false, description: "metric or imperial"

  def call(city:, units: 'metric')
    require 'httparty'

    response = HTTParty.get(
      'https://api.openweathermap.org/data/2.5/weather',
      query: {
        q: city,
        units: units,
        appid: ENV['OPENWEATHER_API_KEY']
      }
    )

    if response.success?
      weather = response.parsed_response
      temp = weather['main']['temp']
      desc = weather['weather'][0]['description']

      message = "Weather in #{city}: #{temp}° #{desc}"
      send_message(message)

      {
        success: true,
        temperature: temp,
        description: desc
      }
    else
      { success: false, error: response.message }
    end
  end
end
```

### Database Backup

```ruby
class BackupDatabase < Fang::Skill
  description "Create a backup of the database"

  param :format, :string, required: false, description: "sql or json"

  def call(format: 'sql')
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')

    case format
    when 'sql'
      backup_file = "storage/backups/db_#{timestamp}.sql"
      system("sqlite3 storage/data.db .dump > #{backup_file}")
    when 'json'
      backup_file = "storage/backups/db_#{timestamp}.json"
      # Export data as JSON
      data = {
        conversations: Conversation.all.as_json,
        messages: Message.all.as_json
      }
      File.write(backup_file, JSON.pretty_generate(data))
    end

    send_message("Database backed up to #{backup_file}")

    { success: true, file: backup_file }
  end
end
```

## Best Practices

### 1. Single Responsibility

Each skill should do one thing well:

```ruby
# Good: Focused on one task
class SendEmail < Fang::Skill
  def call(to:, subject:, body:)
    # Send email
  end
end

# Bad: Does too many things
class EmailAndNotify < Fang::Skill
  def call(...)
    send_email
    send_sms
    post_to_slack
    update_database
  end
end
```

### 2. Error Handling

Always handle errors gracefully:

```ruby
def call(**params)
  result = risky_operation
  { success: true, result: result }
rescue SpecificError => e
  Fang.logger.error "Operation failed: #{e.message}"
  { success: false, error: e.message }
rescue => e
  { success: false, error: "Unexpected error: #{e.message}" }
end
```

### 3. Validation

Validate parameters:

```ruby
def call(email:, **params)
  unless email.match?(/\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i)
    return { success: false, error: "Invalid email format" }
  end

  # Continue with valid email
end
```

### 4. Logging

Log important events:

```ruby
def call(**params)
  Fang.logger.info "#{self.class.name} started with: #{params.inspect}"

  result = do_work

  Fang.logger.info "#{self.class.name} completed successfully"

  { success: true, result: result }
end
```

### 5. Testing

Test skills in console:

```ruby
./openfang.rb console

# Load skill manually
load 'skills/my_skill.rb'

# Test it
result = MySkill.new.call(param: 'value')
puts result.inspect

# Test via loader
result = Fang::SkillLoader.run('my_skill', param: 'value')
```

## Loading Skills

Skills are loaded automatically at framework startup:

```ruby
# In fang/bootstrap.rb
Fang::SkillLoader.load_all
```

To reload during development:

```ruby
./openfang.rb console
> Fang::SkillLoader.reload!
```

## Registering Skills

Register in database for tracking:

```ruby
Fang::SkillRecord.create!(
  name: 'skill_name',
  description: 'What it does',
  file_path: 'skills/skill_name.rb',
  class_name: 'SkillName'
)
```

Or let AI do it via `run_code` tool:

```ruby
# AI executes this
Fang::SkillRecord.create!(
  name: 'send_email',
  description: 'Send email via SMTP',
  file_path: 'skills/send_email.rb',
  class_name: 'SendEmail'
)
```

## Using Skills

### Via Console

```ruby
./openfang.rb console
> Fang::SkillLoader.run('skill_name', param: 'value')
```

### Via MCP Tool

AI uses `run_skill` tool:

```json
{
  "tool": "run_skill",
  "parameters": {
    "skill_name": "send_email",
    "parameters": {
      "to": "user@example.com",
      "subject": "Hello",
      "body": "Hi there!"
    }
  }
}
```

### Via Scheduled Task

```ruby
Fang::ScheduledTask.create!(
  title: "Send reminder",
  scheduled_for: 1.hour.from_now,
  skill_name: "send_email",
  parameters: { to: "user@example.com", subject: "Reminder" }
)
```

## Documentation

- Base class: `fang/skill_loader.rb`
- Examples: `skills/base.rb`
- Database model: `fang/models/skill_record.rb`
- MCP tool: `fang/tools/run_skill_tool.rb`

**Skills ready!** Create Ruby classes in `skills/` directory. 🛠️
