# frozen_string_literal: true

module Ai
  class AiPage < ActiveRecord::Base
    self.table_name = 'ai_pages'

    include HasStatus

    # Validations
    validates :title, presence: true
    validates :slug, presence: true, uniqueness: true
    validates :content, length: { maximum: 1_000_000 }, allow_blank: true
    validates :status, presence: true, inclusion: { in: %w[draft published archived] }

    has_many :conversations, foreign_key: :ai_page_id, dependent: :nullify
    has_many :canvas_components, dependent: :destroy

    # Statuses
    statuses :draft, :published, :archived
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_validation :generate_slug, if: -> { slug.blank? }

    # Methods
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

      counter = 1
      while AiPage.exists?(slug: slug)
        self.slug = "#{base_slug}-#{counter}"
        counter += 1
      end
    end
  end
end
