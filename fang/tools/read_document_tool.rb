# frozen_string_literal: true

module Fang
  module Tools
    class ReadDocumentTool < FastMcp::Tool
      tool_name 'read_document'
      description 'Read the extracted text content of a document. Parses on first read if needed.'

      arguments do
        required(:document_id).filled(:integer).description('Document ID')
        optional(:reparse).filled(:bool).description('Force re-parsing of the document')
      end

      def call(document_id:, reparse: false)
        doc = Document.find(document_id)

        if reparse || doc.extracted_text.blank?
          doc.parse_content!
          doc.reload
        end

        {
          success: true,
          id: doc.id,
          name: doc.name,
          content_type: doc.content_type,
          status: doc.status,
          text: doc.extracted_text,
          metadata: doc.parsed_metadata
        }
      rescue ActiveRecord::RecordNotFound
        { success: false, error: "Document #{document_id} not found" }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
