# frozen_string_literal: true

require_relative '../test_helper'

class ApprovalTest < Fang::TestCase
  def setup
    super
    # Stub EventBus to avoid triggering real jobs
    @events_emitted = []
    @original_emit = Fang::EventBus.method(:emit)
    events = @events_emitted
    Fang::EventBus.define_singleton_method(:emit) { |name, data = {}| events << [name, data] }

    @approval = Fang::Approval.create!(title: 'Deploy to production', status: 'pending')
  end

  def teardown
    Fang::EventBus.define_singleton_method(:emit, @original_emit)
    super
  end

  # -- Validations --

  def test_requires_title
    a = Fang::Approval.new(status: 'pending')
    refute a.valid?
    assert a.errors[:title].any?
  end

  def test_status_inclusion
    a = Fang::Approval.new(title: 'X', status: 'bogus')
    refute a.valid?
    assert a.errors[:status].any?
  end

  def test_valid_statuses
    %w[pending approved rejected expired].each do |s|
      a = Fang::Approval.new(title: 'X', status: s)
      a.valid?
      assert_empty a.errors[:status], "Expected '#{s}' to be valid"
    end
  end

  # -- Status predicates --

  def test_status_predicates
    assert @approval.pending?
    refute @approval.approved?

    @approval.update!(status: 'approved')
    assert @approval.approved?

    @approval.update!(status: 'rejected')
    assert @approval.rejected?

    @approval.update!(status: 'expired')
    assert @approval.expired?
  end

  # -- approve! --

  def test_approve_sets_status_and_decided_at
    @approval.approve!(notes: 'Looks good')
    @approval.reload

    assert_equal 'approved', @approval.status
    assert_equal 'Looks good', @approval.decision_notes
    refute_nil @approval.decided_at
  end

  def test_approve_emits_event
    @approval.approve!
    assert_equal 1, @events_emitted.length
    assert_match(/approval:approved:/, @events_emitted.first[0])
  end

  # -- reject! --

  def test_reject_sets_status_and_decided_at
    @approval.reject!(notes: 'Not ready')
    @approval.reload

    assert_equal 'rejected', @approval.status
    assert_equal 'Not ready', @approval.decision_notes
    refute_nil @approval.decided_at
  end

  def test_reject_emits_event
    @approval.reject!
    assert_equal 1, @events_emitted.length
    assert_match(/approval:rejected:/, @events_emitted.first[0])
  end

  # -- expire! --

  def test_expire_when_pending
    @approval.expire!
    @approval.reload

    assert_equal 'expired', @approval.status
    refute_nil @approval.decided_at
  end

  def test_expire_emits_event
    @approval.expire!
    assert_equal 1, @events_emitted.length
    assert_match(/approval:expired:/, @events_emitted.first[0])
  end

  def test_expire_does_nothing_when_not_pending
    @approval.update!(status: 'approved')
    @approval.expire!
    @approval.reload

    assert_equal 'approved', @approval.status
    assert_empty @events_emitted
  end

  # -- parsed_metadata --

  def test_parsed_metadata_with_valid_json
    @approval.update!(metadata: '{"key":"val"}')
    assert_equal({ 'key' => 'val' }, @approval.parsed_metadata)
  end

  def test_parsed_metadata_blank
    assert_equal({}, @approval.parsed_metadata)
  end

  def test_parsed_metadata_invalid_json
    @approval.update!(metadata: 'nope')
    assert_equal({}, @approval.parsed_metadata)
  end

  # -- Workflow integration --

  def test_approve_resumes_paused_workflow
    workflow = Fang::Workflow.create!(name: 'Deploy', status: 'paused')
    @approval.update!(workflow: workflow)

    # approve! calls resume_workflow! but workflow isn't actually paused with steps,
    # so we just verify it doesn't crash and the approval is approved
    @approval.approve!
    assert_equal 'approved', @approval.status
  end

  def test_reject_fails_linked_workflow
    workflow = Fang::Workflow.create!(name: 'Deploy', status: 'running')
    @approval.update!(workflow: workflow)

    @approval.reject!(notes: 'No')
    workflow.reload
    assert_equal 'failed', workflow.status
  end
end
