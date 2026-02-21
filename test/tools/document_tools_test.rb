# frozen_string_literal: true

require_relative '../test_helper'

class DocumentToolsTest < Fang::ToolTestCase
  def setup
    super
    @dir = File.join(Fang.root, 'workspace', 'documents')
    FileUtils.mkdir_p(@dir)
  end

  def teardown
    # Clean up test files
    Dir[File.join(@dir, 'test_*')].each { |f| FileUtils.rm_f(f) }
    super
  end

  # -- ListDocumentsTool --

  def test_list_documents_all
    Fang::Document.create!(name: 'a.txt', file_path: 'workspace/documents/a.txt', status: 'ready', content_type: 'text/plain')
    Fang::Document.create!(name: 'b.csv', file_path: 'workspace/documents/b.csv', status: 'uploaded', content_type: 'text/csv')

    result = Fang::Tools::ListDocumentsTool.new.call
    assert result[:success]
    assert_equal 2, result[:count]
  end

  def test_list_documents_filter_by_status
    Fang::Document.create!(name: 'a.txt', file_path: 'workspace/documents/a.txt', status: 'ready', content_type: 'text/plain')
    Fang::Document.create!(name: 'b.csv', file_path: 'workspace/documents/b.csv', status: 'uploaded', content_type: 'text/csv')

    result = Fang::Tools::ListDocumentsTool.new.call(status: 'ready')
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 'a.txt', result[:documents].first[:name]
  end

  def test_list_documents_filter_by_content_type
    Fang::Document.create!(name: 'a.txt', file_path: 'workspace/documents/a.txt', status: 'ready', content_type: 'text/plain')
    Fang::Document.create!(name: 'b.csv', file_path: 'workspace/documents/b.csv', status: 'ready', content_type: 'text/csv')

    result = Fang::Tools::ListDocumentsTool.new.call(content_type: 'text/csv')
    assert result[:success]
    assert_equal 1, result[:count]
  end

  # -- ReadDocumentTool --

  def test_read_document
    doc = Fang::Document.create!(
      name: 'test_read.txt',
      file_path: 'workspace/documents/test_read.txt',
      status: 'ready',
      content_type: 'text/plain',
      extracted_text: 'Hello world'
    )

    result = Fang::Tools::ReadDocumentTool.new.call(document_id: doc.id)
    assert result[:success]
    assert_equal 'Hello world', result[:text]
  end

  def test_read_document_auto_parses_if_blank
    path = File.join(@dir, 'test_autoparse.txt')
    File.write(path, 'auto parsed content')

    doc = Fang::Document.create!(
      name: 'test_autoparse.txt',
      file_path: 'workspace/documents/test_autoparse.txt',
      status: 'uploaded',
      content_type: 'text/plain',
      extracted_text: nil
    )

    result = Fang::Tools::ReadDocumentTool.new.call(document_id: doc.id)
    assert result[:success]
    assert_equal 'auto parsed content', result[:text]
  end

  def test_read_document_reparse
    path = File.join(@dir, 'test_reparse.txt')
    File.write(path, 'reparsed content')

    doc = Fang::Document.create!(
      name: 'test_reparse.txt',
      file_path: 'workspace/documents/test_reparse.txt',
      status: 'ready',
      content_type: 'text/plain',
      extracted_text: 'old content'
    )

    result = Fang::Tools::ReadDocumentTool.new.call(document_id: doc.id, reparse: true)
    assert result[:success]
    assert_equal 'reparsed content', result[:text]
  end

  def test_read_document_not_found
    result = Fang::Tools::ReadDocumentTool.new.call(document_id: 99999)
    refute result[:success]
    assert_match(/not found/, result[:error])
  end

  # -- CreateDocumentTool --

  def test_create_document
    result = Fang::Tools::CreateDocumentTool.new.call(
      name: 'test_created.txt',
      content: 'file content here'
    )

    assert result[:success]
    refute_nil result[:document_id]
    assert_equal 'test_created.txt', result[:name]

    doc = Fang::Document.find(result[:document_id])
    assert File.exist?(File.join(Fang.root, doc.file_path))
  ensure
    FileUtils.rm_f(File.join(@dir, 'test_created.txt'))
  end

  def test_create_document_unique_filename
    File.write(File.join(@dir, 'test_dup.txt'), 'existing')

    result = Fang::Tools::CreateDocumentTool.new.call(
      name: 'test_dup.txt',
      content: 'new content'
    )

    assert result[:success]
    assert_equal 'test_dup_1.txt', result[:name]
  ensure
    FileUtils.rm_f(File.join(@dir, 'test_dup.txt'))
    FileUtils.rm_f(File.join(@dir, 'test_dup_1.txt'))
  end
end
