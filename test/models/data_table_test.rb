# frozen_string_literal: true

require_relative '../test_helper'

class DataTableTest < Fang::TestCase
  def setup
    super
    @schema = [
      { 'name' => 'email', 'type' => 'string', 'required' => true },
      { 'name' => 'age', 'type' => 'integer', 'required' => false }
    ]
    @dt = Fang::DataTable.create!(
      name: 'Contacts',
      table_name: 'dt_contacts',
      schema_definition: @schema.to_json,
      status: 'active'
    )
  end

  def teardown
    @dt&.drop_physical_table!
    # Clean any other dt_ tables that may have been created
    ActiveRecord::Base.connection.tables.select { |t| t.start_with?('dt_') }.each do |t|
      ActiveRecord::Base.connection.drop_table(t, if_exists: true)
    end
    super
  end

  # -- Validations --

  def test_requires_name
    dt = Fang::DataTable.new(table_name: 'dt_x', status: 'active')
    refute dt.valid?
    assert dt.errors[:name].any?
  end

  def test_requires_table_name
    dt = Fang::DataTable.new(name: 'X', status: 'active')
    refute dt.valid?
    assert dt.errors[:table_name].any?
  end

  def test_table_name_must_start_with_dt_prefix
    dt = Fang::DataTable.new(name: 'X', table_name: 'contacts', status: 'active')
    refute dt.valid?
    assert dt.errors[:table_name].any?
  end

  def test_table_name_uniqueness
    dup = Fang::DataTable.new(name: 'Dup', table_name: 'dt_contacts', status: 'active')
    refute dup.valid?
    assert dup.errors[:table_name].any?
  end

  def test_valid_table_name_format
    dt = Fang::DataTable.new(name: 'X', table_name: 'dt_my_table_1', status: 'active')
    dt.valid?
    assert_empty dt.errors[:table_name]
  end

  # -- Status predicates --

  def test_status_predicates
    assert @dt.active?
    refute @dt.archived?

    @dt.update!(status: 'archived')
    assert @dt.archived?
    refute @dt.active?
  end

  # -- Schema parsing --

  def test_parsed_schema
    result = @dt.parsed_schema
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert_equal 'email', result[0]['name']
  end

  def test_parsed_schema_blank
    @dt.update!(schema_definition: '')
    assert_equal [], @dt.parsed_schema
  end

  def test_column_names_from_schema
    assert_equal %w[email age], @dt.column_names_from_schema
  end

  # -- Physical table operations --

  def test_create_and_drop_physical_table
    @dt.create_physical_table!
    assert ActiveRecord::Base.connection.table_exists?('dt_contacts')

    @dt.drop_physical_table!
    refute ActiveRecord::Base.connection.table_exists?('dt_contacts')
  end

  # -- Record CRUD --

  def test_insert_record
    @dt.create_physical_table!
    record = @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    refute_nil record.id
    assert_equal 'alice@example.com', record.email
    assert_equal 30, record.age
  end

  def test_insert_record_ignores_unknown_columns
    @dt.create_physical_table!
    record = @dt.insert_record('email' => 'bob@example.com', 'unknown_col' => 'ignored')
    refute_nil record.id
    assert_equal 'bob@example.com', record.email
  end

  def test_update_record
    @dt.create_physical_table!
    record = @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    updated = @dt.update_record(record.id, 'age' => 31)
    assert_equal 31, updated.age
  end

  def test_delete_record
    @dt.create_physical_table!
    record = @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.delete_record(record.id)
    assert_equal 0, @dt.record_count
  end

  # -- query_records --

  def test_query_records_basic
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records
    assert_equal 2, results.length
  end

  def test_query_records_with_equals_filter
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(filters: [{ 'column' => 'email', 'operator' => '=', 'value' => 'alice@example.com' }])
    assert_equal 1, results.length
    assert_equal 'alice@example.com', results.first.email
  end

  def test_query_records_with_not_equals_filter
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(filters: [{ 'column' => 'email', 'operator' => '!=', 'value' => 'alice@example.com' }])
    assert_equal 1, results.length
    assert_equal 'bob@example.com', results.first.email
  end

  def test_query_records_with_greater_than_filter
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(filters: [{ 'column' => 'age', 'operator' => '>', 'value' => 27 }])
    assert_equal 1, results.length
  end

  def test_query_records_with_less_than_filter
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(filters: [{ 'column' => 'age', 'operator' => '<', 'value' => 27 }])
    assert_equal 1, results.length
  end

  def test_query_records_with_like_filter
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(filters: [{ 'column' => 'email', 'operator' => 'like', 'value' => 'alice' }])
    assert_equal 1, results.length
  end

  def test_query_records_sorting
    @dt.create_physical_table!
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    @dt.insert_record('email' => 'bob@example.com', 'age' => 25)

    results = @dt.query_records(sort_by: 'age', sort_dir: 'asc')
    assert_equal 25, results.first.age
    assert_equal 30, results.last.age
  end

  def test_query_records_pagination
    @dt.create_physical_table!
    5.times { |i| @dt.insert_record('email' => "user#{i}@example.com", 'age' => 20 + i) }

    page1 = @dt.query_records(page: 1, per_page: 2)
    page2 = @dt.query_records(page: 2, per_page: 2)

    assert_equal 2, page1.length
    assert_equal 2, page2.length
    refute_equal page1.first.id, page2.first.id
  end

  # -- record_count --

  def test_record_count
    @dt.create_physical_table!
    assert_equal 0, @dt.record_count
    @dt.insert_record('email' => 'alice@example.com', 'age' => 30)
    assert_equal 1, @dt.record_count
  end

  def test_record_count_no_table
    assert_equal 0, @dt.record_count
  end
end
