# frozen_string_literal: true

require 'roda'
require 'tilt/erubi'
require 'json'

module Ai
  module Web
    class App < Roda
      plugin :render, views: File.expand_path('views', __dir__)
      plugin :public, root: File.expand_path('public', __dir__)
      plugin :json
      plugin :halt
      plugin :all_verbs
      plugin :symbol_views

      # Make models available in views
      plugin :render_locals, locals: {
        Conversation: Ai::Conversation,
        Message: Ai::Message,
        SkillRecord: Ai::SkillRecord,
        Config: Ai::Config
      }

      route do |r|
        # Root - redirect to conversations
        r.root do
          r.redirect '/conversations'
        end

        # Conversations routes
        r.on 'conversations' do
          # List all conversations
          r.is do
            r.get do
              @conversations = Conversation.recent.limit(50)
              view :conversations_index
            end

            # Create new conversation
            r.post do
              conversation = Conversation.create!(
                title: r.params['title'] || 'New Conversation',
                source: 'web'
              )
              r.redirect "/conversations/#{conversation.id}"
            end
          end

          # Individual conversation
          r.on Integer do |id|
            @conversation = Conversation.find(id)

            r.is do
              r.get do
                @messages = @conversation.messages.chronological
                view :conversation_show
              end
            end

            # Messages for this conversation
            r.on 'messages' do
              r.post do
                content = r.params['content']

                unless content && !content.strip.empty?
                  r.halt 400, { error: 'Message content required' }
                end

                # Create user message
                message = @conversation.add_message(
                  role: 'user',
                  content: content
                )

                # Enqueue job to process with AI
                Ai::Jobs::AgentExecutorJob.perform_later(message.id)

                if r.params['turbo']
                  # Turbo Stream response
                  response['Content-Type'] = 'text/vnd.turbo-stream.html'
                  render inline: <<~HTML
                    <turbo-stream action="append" target="messages">
                      <template>
                        #{render('_message', locals: { message: message })}
                      </template>
                    </turbo-stream>
                    <turbo-stream action="reset" target="message-form">
                      <template></template>
                    </turbo-stream>
                  HTML
                else
                  r.redirect "/conversations/#{@conversation.id}"
                end
              end
            end
          end
        end

        # AI Pages
        r.on 'pages' do
          r.is do
            r.get do
              @pages = AiPage.published.recent
              view :pages_index
            end
          end

          r.on String do |slug|
            @page = AiPage.published.find_by!(slug: slug)
            view :page_show
          end
        end

        # Settings
        r.on 'settings' do
          r.is do
            r.get do
              @skills = SkillRecord.all.order(usage_count: :desc)
              @mcp_connections = McpConnection.all
              @config = Config.all_config
              view :settings
            end
          end
        end

        # Health check
        r.on 'health' do
          { status: 'ok', timestamp: Time.now.iso8601 }
        end

        # API routes
        r.on 'api' do
          r.on 'conversations' do
            r.is do
              r.get do
                conversations = Conversation.recent.limit(20).map do |c|
                  {
                    id: c.id,
                    title: c.title,
                    source: c.source,
                    message_count: c.messages.count,
                    last_message_at: c.last_message_at
                  }
                end
                { conversations: conversations }
              end
            end
          end
        end
      end
    end
  end
end
