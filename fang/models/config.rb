# frozen_string_literal: true

module Ai
  class Config < ActiveRecord::Base
    self.table_name = 'config'

    # Validations
    validates :key, presence: true, uniqueness: true
    validates :value_type, presence: true, inclusion: { in: %w[string json encrypted] }

    # Class methods for easy access
    class << self
      def get(key, default = nil)
        record = find_by(key: key)
        return default unless record

        record.parsed_value
      end

      def set(key, value, type: 'string', description: nil)
        record = find_or_initialize_by(key: key)
        record.value_type = type
        record.description = description if description
        record.value = serialize_value(value, type)
        record.save!
        record.parsed_value
      end

      def delete(key)
        find_by(key: key)&.destroy
      end

      def all_config
        all.each_with_object({}) do |record, hash|
          hash[record.key] = record.parsed_value
        end
      end

      private

      def serialize_value(value, type)
        case type
        when 'json'
          value.to_json
        when 'encrypted'
          # TODO: Add encryption support
          value.to_s
        else
          value.to_s
        end
      end
    end

    # Instance methods
    def parsed_value
      case value_type
      when 'json'
        JSON.parse(value) rescue {}
      when 'encrypted'
        # TODO: Add decryption support
        value
      else
        value
      end
    end

    def update_value(new_value)
      self.value = self.class.send(:serialize_value, new_value, value_type)
      save!
      parsed_value
    end
  end
end
