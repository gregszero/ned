# Create a Database Migration

Adds a new table or modifies the database schema.

## Steps

### 1. Create Migration File

File: `workspace/migrations/YYYYMMDDNNNNNN_description.rb`

Use the next number in sequence. Check existing migrations:
```bash
ls workspace/migrations/
```

Existing migrations use the format `20260216NNNNNN`. For new ones, use today's date.

#### Create Table

```ruby
class CreateThings < ActiveRecord::Migration[8.0]
  def change
    create_table :things do |t|
      t.string :name, null: false
      t.text :description
      t.string :status, default: 'active'
      t.integer :count, default: 0
      t.references :conversation, foreign_key: true
      t.json :metadata, default: {}
      t.timestamps
    end

    add_index :things, :name, unique: true
    add_index :things, :status
  end
end
```

#### Modify Table

```ruby
class AddFieldToThings < ActiveRecord::Migration[8.0]
  def change
    add_column :things, :new_field, :string
    add_index :things, :new_field
  end
end
```

### 2. Create Model

File: `fang/models/thing.rb`

```ruby
# frozen_string_literal: true

module Fang
  class Thing < ActiveRecord::Base
    self.table_name = 'things'

    # Include concerns as needed
    # include HasStatus  # adds status scopes (e.g., statuses :active, :archived)

    validates :name, presence: true

    scope :recent, -> { order(created_at: :desc) }
  end
end
```

### 3. Run Migration

```bash
./openfang.rb db:migrate
```

## Conventions

- Migration class name matches the file description in PascalCase
- Table names are plural, model class names are singular
- Always use `self.table_name = 'table_name'` in models
- All models live under the `Fang` module
- Models are auto-loaded from `fang/models/` by `bootstrap.rb`
- Use `HasStatus` concern for models with status fields — gives you scopes like `.published`, `.draft`
- Prefer `json` type for flexible metadata columns
