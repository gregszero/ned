# frozen_string_literal: true

module Ai
  module HasStatus
    extend ActiveSupport::Concern

    class_methods do
      def statuses(*names)
        names.each do |name|
          scope name, -> { where(status: name.to_s) }
          define_method(:"#{name}?") { status == name.to_s }
        end
      end
    end
  end
end
