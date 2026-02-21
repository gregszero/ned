# frozen_string_literal: true

module Fang
  module Resources
    class GuideResource < FastMcp::Resource
      GUIDES_DIR = File.expand_path('../../../workspace/guides', __FILE__)

      TOPICS = {
        'gmail'         => 'Gmail patterns and query syntax',
        'canvas'        => 'Canvas components, widgets, layouts, data binding, action buttons',
        'data-tables'   => 'Dynamic data table creation, CRUD, column types',
        'documents'     => 'Document upload, parsing, and creation',
        'approvals'     => 'Approval gates and workflow integration',
        'automation'    => 'Event triggers, multi-step workflows, step types',
        'design-system' => 'CSS tokens, component classes, Tailwind utilities',
        'python'        => 'Python execution, virtualenv, skills'
      }.freeze

      uri 'guide://index'
      resource_name 'Guide Index'
      description 'Lists all available reference guides. Read a specific guide with guide://{topic}'

      def content
        lines = ["# Available Reference Guides\n"]
        lines << "Read a specific guide by its URI (e.g. read the `guide://gmail` resource).\n"
        TOPICS.each do |topic, desc|
          lines << "- `guide://#{topic}` — #{desc}"
        end
        lines.join("\n")
      end

      # Register a resource for each topic
      TOPICS.each do |topic, desc|
        klass = Class.new(FastMcp::Resource) do
          uri "guide://#{topic}"
          resource_name "Guide: #{topic}"
          description desc

          define_method(:content) do
            path = File.join(GUIDES_DIR, "#{topic}.md")
            File.exist?(path) ? File.read(path) : "Guide not found: #{topic}"
          end
        end

        const_set("Guide_#{topic.tr('-', '_').capitalize}", klass)
      end
    end
  end
end
