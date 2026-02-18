# frozen_string_literal: true

module Ai
  class Conversation < ActiveRecord::Base
    self.table_name = 'conversations'

    include HasJsonDefaults

    # Associations
    belongs_to :ai_page, class_name: 'Ai::AiPage', optional: true
    has_many :messages, dependent: :destroy
    has_many :sessions, dependent: :destroy

    # Validations
    validates :source, presence: true, inclusion: { in: %w[web cli scheduled_task whatsapp] }
    validates :slug, uniqueness: true, allow_nil: true

    # Scopes
    scope :recent, -> { order(last_message_at: :desc) }
    scope :by_source, ->(source) { where(source: source) }

    # Defaults
    json_defaults context: {}

    # Callbacks
    after_initialize :set_last_message_at, if: :new_record?
    before_validation :generate_slug, if: -> { slug.blank? }

    # Methods
    def add_message(role:, content:, metadata: {})
      messages.create!(
        role: role,
        content: content,
        metadata: metadata
      ).tap do
        touch(:last_message_at)
      end
    end

    def active_session
      sessions.where(status: 'running').order(created_at: :desc).first
    end

    def latest_messages(limit = 10)
      messages.order(created_at: :desc).limit(limit).reverse
    end

    def ensure_canvas!
      return ai_page if ai_page

      page = Ai::AiPage.create!(title: title.presence || 'Untitled Canvas', content: '', status: 'published', published_at: Time.current)
      update!(ai_page_id: page.id)
      reload.ai_page
    end

    def broadcast_channel
      "canvas:#{ensure_canvas!.id}"
    end

    private

    def set_last_message_at
      self.last_message_at ||= Time.current
    end

    def generate_slug
      base = (title.presence || "chat-#{SecureRandom.hex(3)}").parameterize
      self.slug = base
      counter = 1
      while Conversation.where.not(id: id).exists?(slug: slug)
        self.slug = "#{base}-#{counter}"
        counter += 1
      end
    end
  end
end
