# Database Management

Manages the OpenFang database including migrations, resets, and queries.

## What this does

Provides commands and guidance for managing the OpenFang database:
- Running migrations
- Resetting database
- Creating/dropping database
- Querying data
- Backing up data

## When to use

Use this skill when you need to:
- Run new migrations
- Reset database state
- Query data
- Fix database issues
- Backup or restore data

## Database Overview

**OpenFang uses:**
- **Development**: SQLite (file: `storage/data.db`)
- **Production**: PostgreSQL (recommended)
- **ORM**: ActiveRecord 8.x
- **Migrations**: Located in `workspace/migrations/`

**Tables (17 total):**

1. `conversations` - Chat conversations
2. `messages` - Chat messages
3. `sessions` - Container sessions
4. `scheduled_tasks` - Future task execution
5. `skills` - Ruby skill metadata
6. `mcp_connections` - External MCP servers
7. `config` - Key-value configuration
8. `pages` - AI-generated pages
9-17. `solid_queue_*` - Background job tables

## Commands

### Run Migrations

Apply all pending migrations:

```bash
bundle exec rake db:migrate
```

Or via CLI:
```bash
./openfang.rb db:migrate
```

**When to use:**
- After pulling new code
- After adding new migrations
- Initial setup

### Reset Database

Drop all tables and re-run migrations:

```bash
bundle exec rake db:reset
```

Or via CLI:
```bash
./openfang.rb db:reset
```

**Warning:** This deletes ALL data!

**When to use:**
- Starting fresh
- Fixing corruption
- Development/testing

### Create Database

For PostgreSQL:

```bash
bundle exec rake db:create
```

**Note:** SQLite creates database automatically.

### Drop Database

```bash
bundle exec rake db:drop
```

**Warning:** Permanently deletes database!

### Interactive Console

Query database directly:

```bash
./openfang.rb console
```

Then use ActiveRecord:

```ruby
# Count conversations
Fang::Conversation.count

# List recent messages
Fang::Message.order(created_at: :desc).limit(10)

# Find conversation
conv = Fang::Conversation.find(1)

# See conversation messages
conv.messages.each { |m| puts "#{m.role}: #{m.content}" }

# Create test data
Fang::Conversation.create!(title: "Test", source: "web")

# Exit
exit
```

## Database Schema

### conversations

```ruby
t.string :title
t.string :source          # web, cli
t.datetime :last_message_at
t.json :context
t.timestamps
```

**Associations:**
- `has_many :messages`
- `has_many :sessions`

### messages

```ruby
t.references :conversation
t.text :content
t.string :role            # user, assistant, system
t.boolean :streaming
t.json :metadata
t.timestamps
```

**Associations:**
- `belongs_to :conversation`

### sessions

```ruby
t.references :conversation
t.string :container_id
t.string :status          # starting, running, stopped, error
t.string :session_path
t.datetime :started_at
t.datetime :stopped_at
t.timestamps
```

**Associations:**
- `belongs_to :conversation`

### scheduled_tasks

```ruby
t.string :title
t.text :description
t.datetime :scheduled_for
t.string :status          # pending, running, completed, failed
t.text :result
t.json :parameters
t.string :skill_name
t.timestamps
```

### skills

```ruby
t.string :name           # unique
t.text :description
t.string :file_path
t.string :class_name
t.integer :usage_count
t.json :metadata
t.timestamps
```

### mcp_connections

```ruby
t.string :name           # unique
t.string :transport_type # stdio, sse, http
t.text :command
t.string :url
t.boolean :enabled
t.json :available_tools
t.json :config
t.timestamps
```

### config

```ruby
t.string :key            # unique
t.text :value
t.string :value_type     # string, json, encrypted
t.text :description
t.timestamps
```

### pages

```ruby
t.string :title
t.string :slug           # unique
t.text :content
t.string :status         # draft, published, archived
t.datetime :published_at
t.json :metadata
t.timestamps
```

## Common Queries

### Conversations

```ruby
# List all
Fang::Conversation.all

# Recent conversations
Fang::Conversation.recent.limit(10)

# By source
Fang::Conversation.by_source('web')

# With message count
Fang::Conversation.includes(:messages).map { |c| [c.title, c.messages.count] }

# Find by ID
Fang::Conversation.find(1)
```

### Messages

```ruby
# All messages for conversation
conv = Fang::Conversation.find(1)
conv.messages.chronological

# User messages only
Fang::Message.user_messages

# Assistant messages only
Fang::Message.assistant_messages

# Recent messages
Fang::Message.order(created_at: :desc).limit(20)
```

### Sessions

```ruby
# Active sessions
Fang::Session.active

# Stopped sessions
Fang::Session.stopped

# Sessions with errors
Fang::Session.with_errors

# Old sessions (for cleanup)
Fang::Session.old
```

### Scheduled Tasks

```ruby
# Pending tasks
Fang::ScheduledTask.pending

# Due tasks
Fang::ScheduledTask.due

# Completed tasks
Fang::ScheduledTask.completed

# Failed tasks
Fang::ScheduledTask.failed
```

### Skills

```ruby
# All skills
Fang::SkillRecord.all

# By usage
Fang::SkillRecord.by_usage

# Recent skills
Fang::SkillRecord.recent

# Find by name
Fang::SkillRecord.find_by(name: 'send_email')
```

## Creating Test Data

```ruby
# In console: ./openfang.rb console

# Create conversation
conv = Fang::Conversation.create!(
  title: 'Test Conversation',
  source: 'web'
)

# Add messages
conv.add_message(
  role: 'user',
  content: 'Hello, AI!'
)

conv.add_message(
  role: 'assistant',
  content: 'Hello! How can I help you?'
)

# Create skill
Fang::SkillRecord.create!(
  name: 'test_skill',
  description: 'A test skill',
  file_path: 'skills/test_skill.rb',
  class_name: 'TestSkill'
)

# Create scheduled task
Fang::ScheduledTask.create!(
  title: 'Test Task',
  description: 'Run at midnight',
  scheduled_for: Time.current.end_of_day
)

# Create AI page
Fang::Page.create!(
  title: 'Test Page',
  content: '<h1>Hello World</h1>',
  status: 'published',
  published_at: Time.current
)
```

## Migrations

### Creating New Migration

```ruby
# Create file: workspace/migrations/YYYYMMDDHHMMSS_migration_name.rb

class MigrationName < ActiveRecord::Migration[8.0]
  def change
    create_table :table_name do |t|
      t.string :field_name
      t.timestamps
    end

    add_index :table_name, :field_name
  end
end
```

### Migration Methods

```ruby
# Create table
create_table :users do |t|
  t.string :name
  t.string :email
  t.timestamps
end

# Add column
add_column :users, :phone, :string

# Add index
add_index :users, :email, unique: true

# Add foreign key
add_foreign_key :messages, :conversations

# Remove column
remove_column :users, :phone

# Rename column
rename_column :users, :name, :full_name

# Change column type
change_column :users, :age, :integer

# Drop table
drop_table :users
```

## Backup & Restore

### SQLite Backup

```bash
# Backup
cp storage/data.db storage/data.db.backup

# Restore
cp storage/data.db.backup storage/data.db
```

### PostgreSQL Backup

```bash
# Backup
pg_dump openfang_production > backup.sql

# Restore
psql openfang_production < backup.sql
```

### Export Data

```ruby
# In console
require 'json'

# Export conversations
data = Fang::Conversation.all.map do |c|
  {
    id: c.id,
    title: c.title,
    messages: c.messages.map { |m| { role: m.role, content: m.content } }
  }
end

File.write('conversations.json', JSON.pretty_generate(data))
```

## Troubleshooting

**"PendingMigrationError"**
```bash
bundle exec rake db:migrate
```

**"Table doesn't exist"**
```bash
# Check migrations run
bundle exec rake db:migrate

# Or reset
bundle exec rake db:reset
```

**"Database locked" (SQLite)**
```bash
# Close all connections
# Stop server and queue workers
# Then try again
```

**"Connection refused" (PostgreSQL)**
```bash
# Check PostgreSQL running
pg_isready

# Check connection string
echo $DATABASE_URL
```

**"Disk full"**
```bash
# Check database size
du -h storage/data.db

# Clean up old sessions
./openfang.rb console
> Fang::Session.old.delete_all
```

## Switching to PostgreSQL

1. **Install PostgreSQL**

```bash
# Ubuntu/Debian
sudo apt-get install postgresql

# macOS
brew install postgresql
```

2. **Create Database**

```bash
createdb openfang_development
createdb openfang_production
```

3. **Update Configuration**

Edit `config/database.yml`:

```yaml
development:
  adapter: postgresql
  database: openfang_development
  pool: 5

production:
  adapter: postgresql
  url: <%= ENV['DATABASE_URL'] %>
```

4. **Update .env**

```bash
DATABASE_URL=postgresql://user:password@localhost/openfang_production
```

5. **Run Migrations**

```bash
bundle exec rake db:migrate
```

## Database Console

### SQLite

```bash
sqlite3 storage/data.db

# List tables
.tables

# Schema
.schema conversations

# Query
SELECT * FROM conversations LIMIT 10;

# Exit
.quit
```

### PostgreSQL

```bash
psql openfang_production

# List tables
\dt

# Schema
\d conversations

# Query
SELECT * FROM conversations LIMIT 10;

# Exit
\q
```

## Performance

### Add Indexes

For frequently queried fields:

```ruby
add_index :messages, [:conversation_id, :created_at]
add_index :sessions, :status
add_index :skills, :usage_count
```

### Query Optimization

```ruby
# Bad: N+1 queries
conversations.each do |c|
  puts c.messages.count  # Queries for each conversation
end

# Good: Eager loading
conversations.includes(:messages).each do |c|
  puts c.messages.count  # Single query
end
```

## Documentation

- Migrations: `workspace/migrations/`
- Models: `fang/models/`
- Schema: `bundle exec rake db:schema:dump`
- ActiveRecord Guide: https://guides.rubyonrails.org/active_record_basics.html

**Database ready!** Use `./openfang.rb console` to interact with data. 💾
