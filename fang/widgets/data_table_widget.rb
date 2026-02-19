# frozen_string_literal: true

module Fang
  module Widgets
    class DataTableWidget < BaseWidget
      widget_type 'data_table'
      menu_label 'Data Table'
      menu_icon "\u{1F4CB}"

      def self.refreshable?     = true
      def self.refresh_interval = 30

      def self.default_metadata
        {
          'title'        => 'Table',
          'model'        => nil,
          'columns'      => [],
          'default_sort' => { 'column' => 'created_at', 'direction' => 'desc' },
          'filters'      => [],
          'per_page'     => 25,
          'max_height'   => '400px',
          'data_source'  => nil
        }
      end

      FORMATTERS = %w[badge code date truncate].freeze
      ALLOWED_OPERATORS = %w[= != > < >= <= like].freeze

      def render_content
        title    = @metadata['title'] || 'Table'
        columns  = @metadata['columns'] || []
        max_h    = @metadata['max_height'] || '400px'

        return empty_state if columns.empty?

        if @metadata['model']
          rows_html, has_more = render_page(page: 1)
          table_html = build_table(columns, rows_html, has_more, page: 1)
        else
          table_html = build_static_table(columns)
        end

        filter_chips = build_filter_chips

        <<~HTML
          <div class="data-table-widget flex flex-col gap-2 p-3">
            <div class="flex items-center justify-between">
              <div class="text-sm font-semibold" style="color:var(--foreground)">#{h title}</div>
              #{filter_chips}
            </div>
            <div class="data-table-scroll" style="max-height:#{h max_h}">
              #{table_html}
            </div>
          </div>
        HTML
      end

      def render_page(page:, sort_col: nil, sort_dir: nil, filters: nil)
        model_class = resolve_model
        return ['', false] unless model_class

        columns  = @metadata['columns'] || []
        per_page = (@metadata['per_page'] || 25).to_i.clamp(1, 100)
        sort_col ||= @metadata.dig('default_sort', 'column') || 'created_at'
        sort_dir ||= @metadata.dig('default_sort', 'direction') || 'desc'
        sort_dir = sort_dir.to_s.downcase == 'asc' ? 'asc' : 'desc'
        filters  ||= @metadata['filters'] || []

        scope = model_class.all
        scope = apply_filters(scope, filters)

        # Validate sort column exists
        if model_class.column_names.include?(sort_col.to_s)
          scope = scope.order(sort_col => sort_dir)
        else
          scope = scope.order(created_at: :desc)
        end

        total = scope.count
        pagy = Pagy.new(count: total, page: page, limit: per_page)
        records = scope.offset(pagy.offset).limit(pagy.limit)

        rows_html = records.map { |record| build_row(record, columns) }.join
        [rows_html, !pagy.next.nil?]
      end

      def refresh_data!
        new_content = render_content
        if new_content != @component.content
          @component.update!(content: new_content)
          true
        else
          false
        end
      end

      private

      def resolve_model
        name = @metadata['model'].to_s.strip
        return nil if name.empty?

        klass = Fang.const_get(name)
        klass < ActiveRecord::Base ? klass : nil
      rescue NameError
        nil
      end

      def apply_filters(scope, filters)
        Array(filters).each do |f|
          col = f['column'].to_s
          op  = f['operator'].to_s
          val = f['value']
          next unless ALLOWED_OPERATORS.include?(op) && val

          case op
          when '='     then scope = scope.where(col => val)
          when '!='    then scope = scope.where.not(col => val)
          when 'like'  then scope = scope.where("#{col} LIKE ?", "%#{val}%")
          when '>'     then scope = scope.where("#{col} > ?", val)
          when '<'     then scope = scope.where("#{col} < ?", val)
          when '>='    then scope = scope.where("#{col} >= ?", val)
          when '<='    then scope = scope.where("#{col} <= ?", val)
          end
        end
        scope
      end

      def build_table(columns, rows_html, has_more, page:)
        sort_col = @metadata.dig('default_sort', 'column') || 'created_at'
        sort_dir = @metadata.dig('default_sort', 'direction') || 'desc'
        cid = @component.id

        colgroup = columns.map { |col| %(<col style="width:#{col['width'] || 150}px">) }.join

        header = columns.map do |col|
          sortable = col['sortable'] ? ' data-sortable="true"' : ''
          sort_class = ''
          if col['sortable'] && col['key'] == sort_col
            sort_class = " sort-#{sort_dir}"
          end
          %(<th class="data-table-th#{sort_class}" data-col="#{h col['key']}"#{sortable}>#{h col['label'] || col['key']}<span class="col-resize-handle"></span></th>)
        end.join

        sentinel = ''
        if has_more
          next_page = page + 1
          src = "/api/tables/#{cid}/rows?page=#{next_page}"
          sentinel = %(<tr class="data-table-next-page"><td colspan="#{columns.size}"><turbo-frame id="data-table-page-#{cid}-#{next_page}" loading="lazy" src="#{src}"></turbo-frame></td></tr>)
        end

        <<~HTML
          <table class="data-table" data-component-id="#{cid}">
            <colgroup>#{colgroup}</colgroup>
            <thead><tr>#{header}</tr></thead>
            <turbo-frame id="data-table-body-#{cid}" tag="tbody">
              #{rows_html}
              #{sentinel}
            </turbo-frame>
          </table>
        HTML
      end

      def build_static_table(columns)
        result = evaluate_data_source
        rows = result.is_a?(Array) ? result : (@metadata['rows'] || [])

        colgroup = columns.map { |col| %(<col style="width:#{col['width'] || 150}px">) }.join
        header = columns.map { |col| %(<th class="data-table-th">#{h col['label'] || col['key']}</th>) }.join
        rows_html = rows.map do |row|
          cells = Array(row).map { |cell| "<td>#{h cell}</td>" }.join
          "<tr>#{cells}</tr>"
        end.join

        <<~HTML
          <table class="data-table">
            <colgroup>#{colgroup}</colgroup>
            <thead><tr>#{header}</tr></thead>
            <tbody>#{rows_html}</tbody>
          </table>
        HTML
      end

      def build_row(record, columns)
        cells = columns.map do |col|
          val = record.respond_to?(col['key']) ? record.send(col['key']) : nil
          "<td>#{format_cell(val, col['formatter'])}</td>"
        end.join
        "<tr>#{cells}</tr>"
      end

      def format_cell(value, formatter)
        return '<span style="color:var(--muted-foreground)">-</span>' if value.nil?

        case formatter
        when 'badge'
          badge_class = case value.to_s
                        when 'pending'   then 'warning'
                        when 'running'   then 'info'
                        when 'completed', 'active', 'success' then 'success'
                        when 'failed', 'error' then 'error'
                        else ''
                        end
          %(<span class="badge #{badge_class}">#{h value}</span>)
        when 'code'
          %(<code>#{h value}</code>)
        when 'date'
          formatted = value.respond_to?(:strftime) ? value.strftime('%b %d, %Y %H:%M') : h(value)
          formatted
        when 'truncate'
          %(<span class="data-table-truncate">#{h value}</span>)
        else
          h(value)
        end
      end

      def build_filter_chips
        filters = @metadata['filters'] || []
        return '' if filters.empty?

        chips = filters.map do |f|
          %(<span class="badge">#{h f['column']} #{h f['operator']} #{h f['value']}</span>)
        end.join(' ')
        %(<div class="flex gap-1 flex-wrap">#{chips}</div>)
      end

      def empty_state
        %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">No columns configured</div>)
      end
    end
  end
end
