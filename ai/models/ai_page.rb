# frozen_string_literal: true

module Ai
  class AiPage < ActiveRecord::Base
    self.table_name = 'ai_pages'

    # Validations
    validates :title, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :content, presence: true
    validates :status, presence: true, inclusion: { in: %w[draft published archived] }

    # Scopes
    scope :published, -> { where(status: 'published') }
    scope :draft, -> { where(status: 'draft') }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_validation :generate_slug, if: -> { slug.blank? }

    # Methods
    def published?
      status == 'published'
    end

    def publish!
      update!(status: 'published', published_at: Time.current)
    end

    def archive!
      update!(status: 'archived')
    end

    private

    def generate_slug
      return unless title.present?

      base_slug = title.parameterize
      self.slug = base_slug

      # Handle duplicates
      counter = 1
      while AiPage.exists?(slug: slug)
        self.slug = "#{base_slug}-#{counter}"
        counter += 1
      end
    end
  end
end
