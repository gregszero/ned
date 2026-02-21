# frozen_string_literal: true

module Fang
  class Conversation < ActiveRecord::Base
    self.table_name = 'conversations'

    include HasJsonDefaults

    # Associations
    belongs_to :page, class_name: 'Fang::Page', optional: true
    has_many :messages, dependent: :destroy
    has_many :sessions, dependent: :destroy

    # Validations
    validates :source, presence: true, inclusion: { in: %w[web cli scheduled_task whatsapp heartbeat] }
    validates :slug, uniqueness: true, allow_nil: true

    # Scopes
    scope :recent, -> { order(last_message_at: :desc) }
    scope :by_source, ->(source) { where(source: source) }

    # Defaults
    json_defaults context: {}

    # Callbacks
    after_initialize :set_last_message_at, if: :new_record?
    before_validation :generate_slug, if: -> { slug.blank? }

    # Context compression thresholds
    SUMMARY_THRESHOLD = 15
    RESUMMARIZE_INTERVAL = 15

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

    def needs_summary?
      count = messages.count
      return false if count < SUMMARY_THRESHOLD
      return true if context_summary.blank?
      (count - (summary_message_count || 0)) >= RESUMMARIZE_INTERVAL
    end

    def generate_summary!
      msg_count = messages.count
      return unless msg_count >= SUMMARY_THRESHOLD

      # Collect messages for summarization
      msgs = messages.order(:created_at).map do |m|
        role = m.role == 'user' ? 'User' : 'Assistant'
        content = m.content.to_s
        truncated = content.length > 500 ? content[0..500] + '...' : content
        "#{role}: #{truncated}"
      end.join("\n\n")

      # Include previous summary for incremental updates
      prompt = if context_summary.present?
        "Previous summary:\n#{context_summary}\n\nNew messages since last summary:\n#{msgs}\n\nUpdate the summary to include the new messages. Keep it concise (max 500 words)."
      else
        "Summarize this conversation concisely (max 500 words). Focus on: what the user asked for, what was built/done, key decisions made, and current state.\n\n#{msgs}"
      end

      summary = Fang::ToolClassifier.call_haiku(prompt, system: "You summarize conversations for an AI assistant. Be concise and factual. Focus on actions taken, decisions made, and current state. Output only the summary, no preamble.")
      return unless summary

      update_columns(context_summary: summary, summary_message_count: msg_count)
    end

    def compressed_prompt(new_message)
      if context_summary.present?
        "CONVERSATION CONTEXT (summary of #{summary_message_count} previous messages):\n#{context_summary}\n\nUSER REQUEST:\n#{new_message}"
      else
        new_message
      end
    end

    def ensure_canvas!
      return page if page

      page = Fang::Page.create!(title: title.presence || 'Untitled Canvas', content: '', status: 'published', published_at: Time.current)
      update!(page_id: page.id)
      reload.page
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
