# frozen_string_literal: true

module Fang
  class DataTable < ActiveRecord::Base
    self.table_name = 'data_tables'

    include HasStatus

    belongs_to :page, class_name: 'Fang::Page', optional: true

    validates :name, presence: true
    validates :table_name, presence: true, uniqueness: true, format: { with: /\Adt_\w+\z/, message: 'must start with dt_ and contain only word characters' }
    validates :status, inclusion: { in: %w[active archived] }

    statuses :active, :archived

    scope :recent, -> { order(created_at: :desc) }

    def parsed_schema
      return [] if schema_definition.blank?
      JSON.parse(schema_definition)
    rescue JSON::ParserError
      []
    end

    def column_names_from_schema
      parsed_schema.map { |col| col['name'] }
    end

    def record_class
      tbl = table_name
      Class.new(ActiveRecord::Base) do
        self.table_name = tbl
      end
    end

    def record_count
      record_class.count
    rescue
      0
    end

    def create_physical_table!
      columns = parsed_schema
      tbl = table_name

      ActiveRecord::Base.connection.create_table(tbl) do |t|
        columns.each do |col|
          col_type = col['type']&.to_sym || :string
          col_name = col['name']
          required = col['required'] == true

          t.column col_name, col_type, null: !required
        end
        t.timestamps
      end
    end

    def drop_physical_table!
      ActiveRecord::Base.connection.drop_table(table_name, if_exists: true)
    end

    def insert_record(attributes)
      allowed = column_names_from_schema
      filtered = attributes.select { |k, _| allowed.include?(k.to_s) }
      record_class.create!(filtered)
    end

    def update_record(id, attributes)
      allowed = column_names_from_schema
      filtered = attributes.select { |k, _| allowed.include?(k.to_s) }
      record = record_class.find(id)
      record.update!(filtered)
      record
    end

    def delete_record(id)
      record_class.find(id).destroy!
    end

    def query_records(filters: nil, sort_by: nil, sort_dir: 'asc', page: 1, per_page: 25)
      scope = record_class.all

      if filters.is_a?(Array)
        filters.each do |f|
          col = f['column']
          next unless column_names_from_schema.include?(col)

          op = f['operator'] || '='
          val = f['value']

          scope = case op
                  when '=' then scope.where(col => val)
                  when '!=' then scope.where.not(col => val)
                  when '>' then scope.where("#{col} > ?", val)
                  when '<' then scope.where("#{col} < ?", val)
                  when 'like' then scope.where("#{col} LIKE ?", "%#{val}%")
                  else scope
                  end
        end
      end

      if sort_by && column_names_from_schema.include?(sort_by)
        direction = sort_dir.to_s.downcase == 'desc' ? :desc : :asc
        scope = scope.order(sort_by => direction)
      else
        scope = scope.order(id: :desc)
      end

      offset = ([page.to_i, 1].max - 1) * per_page
      scope.offset(offset).limit(per_page)
    end
  end
end
