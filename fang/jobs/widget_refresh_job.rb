# frozen_string_literal: true

module Fang
  module Jobs
    class WidgetRefreshJob < ApplicationJob
      queue_as :default

      def perform
        Fang::Widgets::BaseWidget.registry.each do |type, widget_class|
          next unless widget_class.refreshable? && widget_class.refresh_interval

          interval = widget_class.refresh_interval
          CanvasComponent.where(component_type: type).find_each do |component|
            # Skip if refreshed too recently
            next if component.updated_at > interval.seconds.ago

            widget = widget_class.new(component)
            if widget.refresh_data!
              turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                      "<template>#{widget.render_component_html}</template></turbo-stream>"
              Fang::Web::TurboBroadcast.broadcast("canvas:#{component.page_id}", turbo)
            end
          rescue => e
            Fang.logger.error "Widget refresh failed for #{type}##{component.id}: #{e.message}"
          end
        end
      end
    end
  end
end
