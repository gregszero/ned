# frozen_string_literal: true

require_relative '../test_helper'

class DocumentTest < Fang::TestCase
  def setup
    super
    @doc = Fang::Document.create!(
      name: 'test.txt',
      file_path: 'workspace/documents/test.txt',
      content_type: 'text/plain',
      status: 'uploaded'
    )
  end

  # -- Validations --

  def test_requires_name
    doc = Fang::Document.new(file_path: 'workspace/documents/x.txt', status: 'uploaded')
    refute doc.valid?
    assert doc.errors[:name].any?
  end

  def test_requires_file_path
    doc = Fang::Document.new(name: 'x.txt', status: 'uploaded')
    refute doc.valid?
    assert doc.errors[:file_path].any?
  end

  def test_status_inclusion
    doc = Fang::Document.new(name: 'x.txt', file_path: 'a', status: 'bogus')
    refute doc.valid?
    assert doc.errors[:status].any?
  end

  def test_valid_statuses
    %w[uploaded processing ready error].each do |s|
      doc = Fang::Document.new(name: 'x.txt', file_path: 'a', status: s)
      doc.valid?
      assert_empty doc.errors[:status], "Expected '#{s}' to be valid"
    end
  end

  # -- Status predicates --

  def test_status_predicates
    @doc.update!(status: 'uploaded')
    assert @doc.uploaded?
    refute @doc.processing?

    @doc.update!(status: 'processing')
    assert @doc.processing?

    @doc.update!(status: 'ready')
    assert @doc.ready?

    @doc.update!(status: 'error')
    assert @doc.error?
  end

  # -- parsed_metadata --

  def test_parsed_metadata_with_valid_json
    @doc.update!(metadata: '{"pages":3}')
    assert_equal({ 'pages' => 3 }, @doc.parsed_metadata)
  end

  def test_parsed_metadata_blank
    @doc.update!(metadata: nil)
    assert_equal({}, @doc.parsed_metadata)
  end

  def test_parsed_metadata_invalid_json
    @doc.update!(metadata: 'not json')
    assert_equal({}, @doc.parsed_metadata)
  end

  # -- parse_content! --

  def test_parse_content_sets_ready
    path = File.join(Fang.root, 'workspace', 'documents')
    FileUtils.mkdir_p(path)
    full = File.join(path, 'parse_test.txt')
    File.write(full, "hello world\nsecond line")

    @doc.update!(file_path: 'workspace/documents/parse_test.txt', content_type: 'text/plain')
    @doc.parse_content!
    @doc.reload

    assert_equal 'ready', @doc.status
    assert_equal "hello world\nsecond line", @doc.extracted_text
    meta = @doc.parsed_metadata
    assert_equal 2, meta['line_count']
  ensure
    FileUtils.rm_f(full) if full
  end

  def test_parse_content_sets_error_on_missing_file
    @doc.update!(file_path: 'workspace/documents/nonexistent.txt', content_type: 'text/plain')
    @doc.parse_content!
    @doc.reload

    assert_equal 'error', @doc.status
  end

  # -- Associations --

  def test_belongs_to_page_optional
    assert_nil @doc.page
    assert @doc.valid?
  end

  def test_belongs_to_conversation_optional
    assert_nil @doc.conversation
    assert @doc.valid?
  end

  # -- Scopes --

  def test_recent_scope
    old = Fang::Document.create!(name: 'old.txt', file_path: 'a', status: 'uploaded', created_at: 1.day.ago)
    recent = Fang::Document.create!(name: 'new.txt', file_path: 'b', status: 'uploaded', created_at: Time.current)

    results = Fang::Document.recent.to_a
    assert_equal recent.id, results.first.id
  end
end
