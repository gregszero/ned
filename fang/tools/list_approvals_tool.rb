# frozen_string_literal: true

module Fang
  module Tools
    class ListApprovalsTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'list_approvals'
      description 'List approvals, optionally filtered by status'
      tool_group :automation

      arguments do
        optional(:status).filled(:string).description('Filter by status: pending, approved, rejected, expired')
        optional(:limit).filled(:integer).description('Max results (default 20)')
      end

      def call(status: nil, limit: 20)
        scope = Approval.recent
        scope = scope.where(status: status) if status

        approvals = scope.limit(limit).map do |a|
          {
            id: a.id,
            title: a.title,
            description: a.description,
            status: a.status,
            decision_notes: a.decision_notes,
            decided_at: a.decided_at&.iso8601,
            expires_at: a.expires_at&.iso8601,
            workflow_id: a.workflow_id,
            created_at: a.created_at.iso8601
          }
        end

        { success: true, approvals: approvals, count: approvals.length }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
