# frozen_string_literal: true

module Ai
  module Tools
    class DefineWidgetTool < FastMcp::Tool
      tool_name 'define_widget'
      description 'Define a new widget type at runtime (Ruby class + optional JS behavior)'

      arguments do
        required(:widget_type).filled(:string).description('Unique type key (snake_case, e.g. "countdown_timer")')
        required(:ruby_code).filled(:string).description('Ruby class body inheriting from Ai::Widgets::BaseWidget')
        optional(:js_code).filled(:string).description('Optional JS behavior registered via registerWidget()')
        optional(:menu_label).filled(:string).description('Label shown in canvas context menu')
        optional(:menu_icon).filled(:string).description('Emoji icon for the context menu')
      end

      def call(widget_type:, ruby_code:, js_code: nil, menu_label: nil, menu_icon: nil)
        # Validate widget_type format
        unless widget_type.match?(/\A[a-z][a-z0-9_]*\z/)
          return { success: false, error: 'widget_type must be snake_case (letters, numbers, underscores)' }
        end

        # Write Ruby widget class
        ruby_path = File.expand_path("../../widgets/#{widget_type}_widget.rb", __dir__)
        File.write(ruby_path, ruby_code)

        # Load the new class
        load ruby_path

        # Reset the registry so the new widget type is discoverable
        Ai::Widgets::BaseWidget.reset_registry!

        result = {
          success: true,
          widget_type: widget_type,
          ruby_path: ruby_path
        }

        # Write optional JS behavior
        if js_code && !js_code.strip.empty?
          js_path = File.expand_path("../../web/public/js/widgets/#{widget_type}.js", __dir__)
          File.write(js_path, js_code)
          result[:js_path] = js_path

          # Broadcast a script tag to load the JS in connected browsers
          script_turbo = <<~HTML
            <turbo-stream action="append" target="head">
              <template><script src="/js/widgets/#{widget_type}.js"></script></template>
            </turbo-stream>
          HTML
          Ai::Web::TurboBroadcast.broadcast('notifications', script_turbo)
        end

        Ai.logger.info "Defined new widget type: #{widget_type}"
        result
      rescue SyntaxError => e
        { success: false, error: "Ruby syntax error: #{e.message}" }
      rescue => e
        Ai.logger.error "Failed to define widget: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
