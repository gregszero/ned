# frozen_string_literal: true

module Fang
  module HasJsonDefaults
    extend ActiveSupport::Concern

    class_methods do
      def json_defaults(**columns)
        after_initialize do
          columns.each { |col, default| self[col] ||= default } if new_record?
        end
      end
    end
  end
end
