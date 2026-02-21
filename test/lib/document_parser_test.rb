# frozen_string_literal: true

require_relative '../test_helper'

class DocumentParserTest < Fang::TestCase
  def setup
    super
    @dir = File.join(Fang.root, 'workspace', 'documents', 'test_parser')
    FileUtils.mkdir_p(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  # -- parse_text --

  def test_parse_text
    path = File.join(@dir, 'hello.txt')
    content = "line one\nline two\nline three"
    File.write(path, content)

    result = Fang::DocumentParser.parse(path, 'text/plain')

    assert_equal content, result[:text]
    assert_equal 3, result[:metadata][:line_count]
    assert_equal content.length, result[:metadata][:character_count]
  end

  # -- parse_csv --

  def test_parse_csv
    path = File.join(@dir, 'data.csv')
    File.write(path, "name,age\nAlice,30\nBob,25\n")

    result = Fang::DocumentParser.parse(path, 'text/csv')

    refute_nil result[:text]
    assert_includes result[:text], 'Alice'
    assert_includes result[:text], 'Bob'
    assert_equal 2, result[:metadata][:row_count]
    assert_equal %w[name age], result[:metadata][:columns]
  end

  # -- application/json dispatches to parse_text --

  def test_parse_json_file
    path = File.join(@dir, 'config.json')
    File.write(path, '{"key":"value"}')

    result = Fang::DocumentParser.parse(path, 'application/json')

    assert_equal '{"key":"value"}', result[:text]
    assert_equal 1, result[:metadata][:line_count]
  end

  # -- Unsupported content type --

  def test_unsupported_content_type
    result = Fang::DocumentParser.parse('/tmp/nope', 'application/octet-stream')

    assert_nil result[:text]
    assert_match(/Unsupported/, result[:metadata][:error])
  end

  # -- Error handling (file not found) --

  def test_parse_text_file_not_found
    result = Fang::DocumentParser.parse('/tmp/nonexistent_file.txt', 'text/plain')

    assert_nil result[:text]
    assert result[:metadata][:error]
  end
end
