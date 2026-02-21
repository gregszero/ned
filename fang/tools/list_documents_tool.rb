# frozen_string_literal: true

module Fang
  module Tools
    class ListDocumentsTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'list_documents'
      description 'List uploaded documents, optionally filtered by status or content type'
      tool_group :documents

      arguments do
        optional(:status).filled(:string).description('Filter by status: uploaded, processing, ready, error')
        optional(:content_type).filled(:string).description('Filter by MIME type (e.g. "application/pdf")')
        optional(:limit).filled(:integer).description('Max results (default 20)')
      end

      def call(status: nil, content_type: nil, limit: 20)
        scope = Document.recent
        scope = scope.where(status: status) if status
        scope = scope.where(content_type: content_type) if content_type

        documents = scope.limit(limit).map do |doc|
          {
            id: doc.id,
            name: doc.name,
            content_type: doc.content_type,
            file_size: doc.file_size,
            status: doc.status,
            description: doc.description,
            has_text: doc.extracted_text.present?,
            metadata: doc.parsed_metadata,
            created_at: doc.created_at.iso8601
          }
        end

        { success: true, documents: documents, count: documents.length }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
