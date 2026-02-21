# frozen_string_literal: true

require_relative '../test_helper'

class DataTableToolsTest < Fang::ToolTestCase
  def teardown
    ActiveRecord::Base.connection.tables.select { |t| t.start_with?('dt_') }.each do |t|
      ActiveRecord::Base.connection.drop_table(t, if_exists: true)
    end
    super
  end

  # -- CreateDataTableTool --

  def test_create_data_table
    result = Fang::Tools::CreateDataTableTool.new.call(
      name: 'Customers',
      columns: [
        { 'name' => 'email', 'type' => 'string', 'required' => true },
        { 'name' => 'score', 'type' => 'integer' }
      ]
    )

    assert result[:success]
    refute_nil result[:data_table_id]
    assert_equal 'dt_customers', result[:table_name]
    assert ActiveRecord::Base.connection.table_exists?('dt_customers')
  end

  def test_create_data_table_invalid_type
    result = Fang::Tools::CreateDataTableTool.new.call(
      name: 'Bad',
      columns: [{ 'name' => 'x', 'type' => 'vector' }]
    )

    refute result[:success]
    assert_match(/Invalid column type/, result[:error])
  end

  # -- ListDataTablesTool --

  def test_list_data_tables
    dt = Fang::DataTable.create!(
      name: 'Items', table_name: 'dt_items',
      schema_definition: [{ 'name' => 'title', 'type' => 'string' }].to_json,
      status: 'active'
    )
    dt.create_physical_table!
    dt.insert_record('title' => 'Widget')

    result = Fang::Tools::ListDataTablesTool.new.call
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 1, result[:tables].first[:record_count]
  end

  # -- QueryDataTableTool --

  def test_query_basic
    dt = create_test_table_with_data

    result = Fang::Tools::QueryDataTableTool.new.call(data_table_id: dt.id)
    assert result[:success]
    assert_equal 2, result[:count]
  end

  def test_query_with_filter
    dt = create_test_table_with_data

    result = Fang::Tools::QueryDataTableTool.new.call(
      data_table_id: dt.id,
      filters: [{ 'column' => 'name', 'operator' => '=', 'value' => 'Alice' }]
    )
    assert result[:success]
    assert_equal 1, result[:count]
  end

  def test_query_with_sorting
    dt = create_test_table_with_data

    result = Fang::Tools::QueryDataTableTool.new.call(
      data_table_id: dt.id, sort_by: 'name', sort_dir: 'asc'
    )
    assert result[:success]
    assert_equal 'Alice', result[:records].first['name']
  end

  def test_query_with_pagination
    dt = create_test_table_with_data

    result = Fang::Tools::QueryDataTableTool.new.call(
      data_table_id: dt.id, page: 1, per_page: 1
    )
    assert result[:success]
    assert_equal 1, result[:count]
  end

  def test_query_not_found
    result = Fang::Tools::QueryDataTableTool.new.call(data_table_id: 99999)
    refute result[:success]
    assert_match(/not found/, result[:error])
  end

  # -- InsertDataRecordTool --

  def test_insert_record
    dt = create_test_table

    result = Fang::Tools::InsertDataRecordTool.new.call(
      data_table_id: dt.id,
      attributes: { 'name' => 'Charlie', 'score' => 100 }
    )
    assert result[:success]
    refute_nil result[:record_id]
    assert_equal 'Charlie', result[:attributes]['name']
  end

  # -- UpdateDataRecordTool --

  def test_update_record
    dt = create_test_table
    record = dt.insert_record('name' => 'Alice', 'score' => 10)

    result = Fang::Tools::UpdateDataRecordTool.new.call(
      data_table_id: dt.id,
      record_id: record.id,
      attributes: { 'score' => 99 }
    )
    assert result[:success]
    assert_equal 99, result[:attributes]['score']
  end

  # -- DeleteDataRecordTool --

  def test_delete_record
    dt = create_test_table
    record = dt.insert_record('name' => 'Alice', 'score' => 10)

    result = Fang::Tools::DeleteDataRecordTool.new.call(
      data_table_id: dt.id, record_id: record.id
    )
    assert result[:success]
    assert_equal 0, dt.record_count
  end

  def test_delete_record_not_found
    dt = create_test_table

    result = Fang::Tools::DeleteDataRecordTool.new.call(
      data_table_id: dt.id, record_id: 99999
    )
    refute result[:success]
    assert result[:error]
  end

  private

  def create_test_table
    dt = Fang::DataTable.create!(
      name: 'People', table_name: "dt_people_#{SecureRandom.hex(4)}",
      schema_definition: [
        { 'name' => 'name', 'type' => 'string' },
        { 'name' => 'score', 'type' => 'integer' }
      ].to_json,
      status: 'active'
    )
    dt.create_physical_table!
    dt
  end

  def create_test_table_with_data
    dt = create_test_table
    dt.insert_record('name' => 'Alice', 'score' => 10)
    dt.insert_record('name' => 'Bob', 'score' => 20)
    dt
  end
end
