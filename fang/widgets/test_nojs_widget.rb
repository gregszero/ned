module Fang
  module Widgets
    class TestNojsWidget < BaseWidget
      widget_type 'test_nojs'
      def render_content
        '<p>no js</p>'
      end
    end
  end
end
