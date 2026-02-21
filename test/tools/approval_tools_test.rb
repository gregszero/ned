# frozen_string_literal: true

require_relative '../test_helper'

class ApprovalToolsTest < Fang::ToolTestCase
  def setup
    super
    # Stub EventBus to avoid triggering real jobs
    @original_emit = Fang::EventBus.method(:emit)
    Fang::EventBus.define_singleton_method(:emit) { |_name, _data = {}| }
  end

  def teardown
    Fang::EventBus.define_singleton_method(:emit, @original_emit)
    super
  end

  # -- CreateApprovalTool --

  def test_create_approval
    result = Fang::Tools::CreateApprovalTool.new.call(title: 'Deploy v2')
    assert result[:success]
    refute_nil result[:approval_id]
    refute_nil result[:notification_id]
    assert_equal 'pending', result[:status]
  end

  def test_create_approval_with_timeout
    result = Fang::Tools::CreateApprovalTool.new.call(
      title: 'Quick approval',
      timeout: '30 minutes'
    )
    assert result[:success]

    # A ScheduledTask should have been created
    task = Fang::ScheduledTask.last
    refute_nil task
    assert_match(/Expire approval/, task.title)
  end

  # -- ListApprovalsTool --

  def test_list_approvals_all
    Fang::Approval.create!(title: 'A', status: 'pending')
    Fang::Approval.create!(title: 'B', status: 'approved')

    result = Fang::Tools::ListApprovalsTool.new.call
    assert result[:success]
    assert_equal 2, result[:count]
  end

  def test_list_approvals_filter_by_status
    Fang::Approval.create!(title: 'A', status: 'pending')
    Fang::Approval.create!(title: 'B', status: 'approved')

    result = Fang::Tools::ListApprovalsTool.new.call(status: 'pending')
    assert result[:success]
    assert_equal 1, result[:count]
    assert_equal 'A', result[:approvals].first[:title]
  end

  # -- ResolveApprovalTool --

  def test_resolve_approve
    approval = Fang::Approval.create!(title: 'X', status: 'pending')

    result = Fang::Tools::ResolveApprovalTool.new.call(
      approval_id: approval.id, decision: 'approve', notes: 'LGTM'
    )
    assert result[:success]
    assert_equal 'approved', result[:status]
    assert_equal 'LGTM', result[:decision_notes]
  end

  def test_resolve_reject
    approval = Fang::Approval.create!(title: 'X', status: 'pending')

    result = Fang::Tools::ResolveApprovalTool.new.call(
      approval_id: approval.id, decision: 'reject', notes: 'Not ready'
    )
    assert result[:success]
    assert_equal 'rejected', result[:status]
  end

  def test_resolve_already_resolved
    approval = Fang::Approval.create!(title: 'X', status: 'approved')

    result = Fang::Tools::ResolveApprovalTool.new.call(
      approval_id: approval.id, decision: 'approve'
    )
    refute result[:success]
    assert_match(/already/, result[:error])
  end

  def test_resolve_not_found
    result = Fang::Tools::ResolveApprovalTool.new.call(
      approval_id: 99999, decision: 'approve'
    )
    refute result[:success]
    assert_match(/not found/, result[:error])
  end
end
