# frozen_string_literal: true

module Fang
  module Concerns
    module ToolGrouping
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def tool_group(group = nil)
          if group
            @tool_group = group.to_sym
          else
            @tool_group || :core
          end
        end
      end
    end
  end
end
