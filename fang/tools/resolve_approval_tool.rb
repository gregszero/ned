# frozen_string_literal: true

module Fang
  module Tools
    class ResolveApprovalTool < FastMcp::Tool
      tool_name 'resolve_approval'
      description 'Approve or reject a pending approval'

      arguments do
        required(:approval_id).filled(:integer).description('Approval ID')
        required(:decision).filled(:string).description('Decision: "approve" or "reject"')
        optional(:notes).filled(:string).description('Decision reasoning')
      end

      def call(approval_id:, decision:, notes: nil)
        approval = Approval.find(approval_id)

        unless approval.pending?
          return { success: false, error: "Approval is already #{approval.status}" }
        end

        case decision.to_s.downcase
        when 'approve'
          approval.approve!(notes: notes)
        when 'reject'
          approval.reject!(notes: notes)
        else
          return { success: false, error: "Invalid decision '#{decision}'. Use 'approve' or 'reject'." }
        end

        {
          success: true,
          approval_id: approval.id,
          title: approval.title,
          status: approval.status,
          decision_notes: approval.decision_notes
        }
      rescue ActiveRecord::RecordNotFound
        { success: false, error: "Approval #{approval_id} not found" }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
