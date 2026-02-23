# frozen_string_literal: true

module Fang
  module Widgets
    class TableWidget < BaseWidget
      widget_type 'table'
      menu_label 'Add Table'
      menu_icon "\u{1F5C2}"
      menu_category 'Content'

      def self.refreshable?     = true
      def self.refresh_interval  = 300

      def self.default_metadata
        { 'title' => 'Table', 'columns' => [], 'rows' => [], 'sortable' => true }
      end

      def render_content
        title = @metadata['title'] || 'Table'
        columns = @metadata['columns'] || []
        rows = @metadata['rows'] || []
        sortable = @metadata['sortable'] != false

        return %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">Empty table</div>) if columns.empty?

        table_attr = sortable ? ' data-ned-table' : ''

        header_html = columns.map { |col| "<th>#{h col}</th>" }.join
        rows_html = rows.map do |row|
          cells = Array(row).map { |cell| "<td>#{h cell}</td>" }.join
          "<tr>#{cells}</tr>"
        end.join

        <<~HTML
          <div class="flex flex-col gap-2 p-3">
            <div class="text-sm font-semibold" style="color:var(--foreground)">#{h title}</div>
            <div class="overflow-x-auto">
              <table#{table_attr}>
                <thead><tr>#{header_html}</tr></thead>
                <tbody>#{rows_html}</tbody>
              </table>
            </div>
          </div>
        HTML
      end

      def refresh_data!
        result = evaluate_data_source
        return false unless result.is_a?(Array)

        columns = @metadata['columns'] || []
        @metadata['rows'] = result.map { |row| Array(row) }
        @component.update!(content: render_content, metadata: @metadata)
        true
      end
    end
  end
end
