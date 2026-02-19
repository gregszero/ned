# frozen_string_literal: true

module Fang
  class SkillRecord < ActiveRecord::Base
    self.table_name = 'skills'

    # Validations
    validates :name, presence: true, uniqueness: true
    validates :file_path, presence: true

    # Scopes
    scope :by_usage, -> { order(usage_count: :desc) }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_create :set_defaults
    before_save :derive_class_name

    # Methods
    def increment_usage!
      increment!(:usage_count)
    end

    def load_and_execute(**params)
      # Load the skill file if the class isn't already defined
      load full_file_path unless Object.const_defined?(class_name)

      # Execute the skill
      klass = class_name.constantize
      klass.new.execute(**params)
    rescue => e
      Fang.logger.error "Failed to execute skill #{name}: #{e.message}"
      raise
    end

    def file_exists?
      File.exist?(full_file_path)
    end

    def full_file_path
      File.join(Fang.root, file_path)
    end

    private

    def set_defaults
      self.metadata ||= {}
      self.usage_count ||= 0
    end

    def derive_class_name
      return if class_name.present?

      # Convert skill name to class name (e.g., "send_email" -> "SendEmail")
      self.class_name = name.split('_').map(&:capitalize).join
    end
  end
end
