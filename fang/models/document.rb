# frozen_string_literal: true

module Fang
  class Document < ActiveRecord::Base
    self.table_name = 'documents'

    include HasStatus

    belongs_to :page, class_name: 'Fang::Page', optional: true
    belongs_to :conversation, optional: true

    validates :name, presence: true
    validates :file_path, presence: true
    validates :status, inclusion: { in: %w[uploaded processing ready error] }

    statuses :uploaded, :processing, :ready, :error

    scope :recent, -> { order(created_at: :desc) }

    def parsed_metadata
      return {} if metadata.blank?
      JSON.parse(metadata)
    rescue JSON::ParserError
      {}
    end

    def parse_content!
      update!(status: 'processing')

      full_path = File.join(Fang.root, file_path)
      result = DocumentParser.parse(full_path, content_type)

      update!(
        extracted_text: result[:text],
        metadata: (parsed_metadata.merge(result[:metadata] || {})).to_json,
        status: result[:text] ? 'ready' : 'error'
      )
    rescue => e
      update!(status: 'error', metadata: { error: e.message }.to_json)
    end
  end
end
