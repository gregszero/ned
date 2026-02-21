# frozen_string_literal: true

require_relative '../test_helper'

class NewRoutesTest < Fang::RouteTestCase
  def setup
    super
    # Stub EventBus to avoid triggering real jobs
    @original_emit = Fang::EventBus.method(:emit)
    Fang::EventBus.define_singleton_method(:emit) { |_name, _data = {}| }
  end

  def teardown
    # Clean up test document files
    Dir[File.join(Fang.root, 'workspace', 'documents', 'test_upload*')].each { |f| FileUtils.rm_f(f) }
    Fang::EventBus.define_singleton_method(:emit, @original_emit)
    super
  end

  # -- POST /documents --

  def test_document_upload
    file = Rack::Test::UploadedFile.new(
      StringIO.new('hello world'),
      'text/plain',
      false,
      original_filename: 'test_upload.txt'
    )

    post '/documents', 'file' => file
    assert_equal 200, last_response.status

    body = JSON.parse(last_response.body)
    assert body['id']
    assert_equal 'test_upload.txt', body['name']
  end

  def test_document_upload_without_file
    post '/documents'
    assert_equal 400, last_response.status
  end

  # -- GET /api/approvals --

  def test_list_pending_approvals
    Fang::Approval.create!(title: 'Pending one', status: 'pending')
    Fang::Approval.create!(title: 'Done', status: 'approved')

    get '/api/approvals'
    assert_equal 200, last_response.status

    body = JSON.parse(last_response.body)
    assert_equal 1, body['approvals'].length
    assert_equal 'Pending one', body['approvals'].first['title']
  end

  def test_list_approvals_with_status_param
    Fang::Approval.create!(title: 'A', status: 'pending')
    Fang::Approval.create!(title: 'B', status: 'approved')

    get '/api/approvals', status: 'approved'
    assert_equal 200, last_response.status

    body = JSON.parse(last_response.body)
    assert_equal 1, body['approvals'].length
    assert_equal 'B', body['approvals'].first['title']
  end

  # -- GET /api/approvals/:id --

  def test_get_approval
    approval = Fang::Approval.create!(title: 'Test', status: 'pending')

    get "/api/approvals/#{approval.id}"
    assert_equal 200, last_response.status

    body = JSON.parse(last_response.body)
    assert_equal 'Test', body['title']
    assert_equal 'pending', body['status']
  end

  # -- POST /api/approvals/:id/decide --

  def test_decide_approve
    approval = Fang::Approval.create!(title: 'Test', status: 'pending')

    post "/api/approvals/#{approval.id}/decide",
         JSON.generate(decision: 'approve', notes: 'Go'),
         'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 'approved', body['status']
  end

  def test_decide_reject
    approval = Fang::Approval.create!(title: 'Test', status: 'pending')

    post "/api/approvals/#{approval.id}/decide",
         JSON.generate(decision: 'reject', notes: 'No'),
         'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal 'rejected', body['status']
  end

  def test_decide_already_resolved
    approval = Fang::Approval.create!(title: 'Test', status: 'approved')

    post "/api/approvals/#{approval.id}/decide",
         JSON.generate(decision: 'approve'),
         'CONTENT_TYPE' => 'application/json'

    assert_equal 400, last_response.status
  end

  # -- POST /api/actions (resolve_approval) --

  def test_resolve_approval_action
    approval = Fang::Approval.create!(title: 'Test', status: 'pending')

    post '/api/actions',
         JSON.generate(action_type: 'resolve_approval', approval_id: approval.id, decision: 'approve'),
         'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body['success']
    assert_equal 'approved', body['status']
  end
end
