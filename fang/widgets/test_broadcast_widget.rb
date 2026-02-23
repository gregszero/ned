module Fang
  module Widgets
    class TestBroadcastWidget < BaseWidget
      widget_type 'test_broadcast'
      def render_content
        '<p>test</p>'
      end
    end
  end
end
