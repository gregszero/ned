# frozen_string_literal: true

require 'csv'

module Fang
  module DocumentParser
    module_function

    def parse(file_path, content_type)
      case content_type
      when 'application/pdf'
        parse_pdf(file_path)
      when 'text/csv', 'application/csv'
        parse_csv(file_path)
      when /spreadsheetml|excel|officedocument\.spreadsheet|vnd\.ms-excel/,
           'application/vnd.oasis.opendocument.spreadsheet'
        parse_excel(file_path)
      when /^text\//
        parse_text(file_path)
      when 'application/json'
        parse_text(file_path)
      else
        { text: nil, metadata: { error: "Unsupported content type: #{content_type}" } }
      end
    end

    def parse_pdf(file_path)
      require 'pdf-reader'
      reader = PDF::Reader.new(file_path)
      pages = reader.pages.map(&:text)
      {
        text: pages.join("\n\n---\n\n"),
        metadata: { page_count: reader.page_count, pages_extracted: pages.length }
      }
    rescue => e
      { text: nil, metadata: { error: e.message } }
    end

    def parse_csv(file_path)
      content = File.read(file_path)
      rows = CSV.parse(content, headers: true)
      text = rows.map { |r| r.to_h.map { |k, v| "#{k}: #{v}" }.join(', ') }.join("\n")
      {
        text: text,
        metadata: { row_count: rows.length, columns: rows.headers }
      }
    rescue => e
      { text: nil, metadata: { error: e.message } }
    end

    def parse_excel(file_path)
      require 'roo'
      spreadsheet = Roo::Spreadsheet.open(file_path)
      sheets = {}
      text_parts = []

      spreadsheet.sheets.each do |sheet_name|
        sheet = spreadsheet.sheet(sheet_name)
        rows = sheet.parse(headers: true)
        sheets[sheet_name] = rows.length
        text_parts << "## #{sheet_name}\n"
        rows.each do |row|
          text_parts << row.map { |k, v| "#{k}: #{v}" }.join(', ')
        end
      end

      {
        text: text_parts.join("\n"),
        metadata: { sheets: sheets, total_rows: sheets.values.sum }
      }
    rescue => e
      { text: nil, metadata: { error: e.message } }
    end

    def parse_text(file_path)
      content = File.read(file_path)
      {
        text: content,
        metadata: { character_count: content.length, line_count: content.lines.count }
      }
    rescue => e
      { text: nil, metadata: { error: e.message } }
    end
  end
end
