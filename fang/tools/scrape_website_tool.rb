# frozen_string_literal: true

require 'json'

module Fang
  module Tools
    class ScrapeWebsiteTool < FastMcp::Tool
      include Fang::Concerns::ToolGrouping

      tool_name 'scrape_website'
      tool_group :web
      description 'Scrape a website with CSS/XPath selectors. Supports basic HTTP, stealth (anti-bot), and playwright (JS rendering) fetchers via the Scrapling Python library.'

      arguments do
        required(:url).filled(:string).description('The URL to scrape')
        optional(:selectors).description('Array of extraction rules: [{name, selector, type (css/xpath), extract (text/html/attr_name), multiple (bool)}]')
        optional(:fetcher_type).filled(:string).description('Fetcher: "basic" (default), "stealth" (anti-bot), or "playwright" (JS rendering)')
        optional(:wait_for).filled(:string).description('CSS selector to wait for before extracting (playwright only)')
      end

      FETCHER_MAP = {
        'basic' => 'Fetcher',
        'stealth' => 'StealthyFetcher',
        'playwright' => 'PlayWrightFetcher'
      }.freeze

      def call(url:, selectors: nil, fetcher_type: 'basic', wait_for: nil)
        fetcher_class = FETCHER_MAP[fetcher_type]
        unless fetcher_class
          return { success: false, error: "Invalid fetcher_type '#{fetcher_type}'. Use: basic, stealth, or playwright" }
        end

        ensure_scrapling_installed!

        code = build_python_code(url, fetcher_class, selectors, wait_for)
        result = Fang::PythonRunner.run_code(code)

        return { success: false, error: result[:error] } unless result[:success]

        parsed = parse_json_result(result[:result])
        return parsed if parsed[:error]

        { success: true, url: url, fetcher: fetcher_type, data: parsed }
      rescue => e
        Fang.logger.error "scrape_website failed: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def ensure_scrapling_installed!
        check = Fang::PythonRunner.run_code('import scrapling; result = "ok"')
        return if check[:success] && check[:result]&.include?('ok')

        Fang.logger.info 'Installing scrapling...'
        install = Fang::PythonRunner.pip_install('scrapling')
        raise "Failed to install scrapling: #{install[:error]}" unless install[:success]
      end

      def build_python_code(url, fetcher_class, selectors, wait_for)
        selectors = normalize_selectors(selectors)
        selectors_json = JSON.generate(selectors)

        <<~PYTHON
          import json
          from scrapling import #{fetcher_class}

          fetcher = #{fetcher_class}()
          #{build_fetch_call(fetcher_class, url, wait_for)}

          selectors = json.loads(#{selectors_json.inspect})
          data = {}

          for sel in selectors:
              name = sel["name"]
              selector_str = sel["selector"]
              sel_type = sel.get("type", "css")
              extract = sel.get("extract", "text")
              multiple = sel.get("multiple", False)

              if sel_type == "xpath":
                  elements = page.find_by_xpath(selector_str)
              else:
                  elements = page.css(selector_str)

              if not elements:
                  data[name] = [] if multiple else None
                  continue

              if multiple:
                  items = []
                  for el in elements:
                      items.append(_extract(el, extract))
                  data[name] = items
              else:
                  el = elements[0] if hasattr(elements, '__getitem__') else elements
                  data[name] = _extract(el, extract)

          result = json.dumps(data)
        PYTHON
          .prepend(extract_helper)
      end

      def extract_helper
        <<~PYTHON
          def _extract(el, mode):
              if mode == "text":
                  return el.text.strip() if hasattr(el, 'text') else str(el).strip()
              elif mode == "html":
                  return el.html if hasattr(el, 'html') else str(el)
              else:
                  return el.attrib.get(mode, "") if hasattr(el, 'attrib') else ""

        PYTHON
      end

      def build_fetch_call(fetcher_class, url, wait_for)
        if fetcher_class == 'PlayWrightFetcher' && wait_for
          "page = fetcher.fetch(#{url.inspect}, wait_selector=#{wait_for.inspect})"
        else
          "page = fetcher.fetch(#{url.inspect})"
        end
      end

      def normalize_selectors(selectors)
        return default_selectors if selectors.nil? || (selectors.is_a?(Array) && selectors.empty?)

        selectors.map do |s|
          s = s.transform_keys(&:to_s) if s.is_a?(Hash)
          {
            'name' => s['name'] || 'result',
            'selector' => s['selector'],
            'type' => s['type'] || 'css',
            'extract' => s['extract'] || 'text',
            'multiple' => s['multiple'] || false
          }
        end
      end

      def default_selectors
        [
          { 'name' => 'title', 'selector' => 'title', 'type' => 'css', 'extract' => 'text', 'multiple' => false },
          { 'name' => 'body_text', 'selector' => 'body', 'type' => 'css', 'extract' => 'text', 'multiple' => false }
        ]
      end

      def parse_json_result(raw)
        return { error: 'No result returned from Python' } unless raw

        JSON.parse(raw)
      rescue JSON::ParserError
        { 'raw' => raw }
      end
    end
  end
end
