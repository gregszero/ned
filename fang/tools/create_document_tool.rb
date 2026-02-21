# frozen_string_literal: true

require 'base64'

module Fang
  module Tools
    class CreateDocumentTool < FastMcp::Tool
      tool_name 'create_document'
      description 'Create a document file programmatically from text or base64 content'

      arguments do
        required(:name).filled(:string).description('Filename (e.g. "report.csv", "data.json")')
        required(:content).filled(:string).description('File content as text, or base64-encoded binary')
        optional(:encoding).filled(:string).description('Content encoding: "text" (default) or "base64"')
        optional(:description).filled(:string).description('Document description')
        optional(:content_type).filled(:string).description('MIME type override (auto-detected if omitted)')
      end

      def call(name:, content:, encoding: 'text', description: nil, content_type: nil)
        require 'marcel'

        # Write file
        dir = File.join(Fang.root, 'workspace', 'documents')
        FileUtils.mkdir_p(dir)

        # Ensure unique filename
        base = File.basename(name, File.extname(name))
        ext = File.extname(name)
        file_name = name
        counter = 1
        while File.exist?(File.join(dir, file_name))
          file_name = "#{base}_#{counter}#{ext}"
          counter += 1
        end

        full_path = File.join(dir, file_name)
        relative_path = "workspace/documents/#{file_name}"

        if encoding == 'base64'
          File.binwrite(full_path, Base64.decode64(content))
        else
          File.write(full_path, content)
        end

        # Detect MIME type
        detected_type = content_type || Marcel::MimeType.for(Pathname.new(full_path), name: file_name)

        doc = Document.create!(
          name: file_name,
          content_type: detected_type,
          file_size: File.size(full_path),
          file_path: relative_path,
          description: description,
          status: 'uploaded'
        )

        # Auto-parse
        doc.parse_content!

        {
          success: true,
          document_id: doc.id,
          name: doc.name,
          file_path: doc.file_path,
          content_type: doc.content_type,
          status: doc.reload.status
        }
      rescue => e
        { success: false, error: e.message }
      end
    end
  end
end
