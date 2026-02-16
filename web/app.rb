# frozen_string_literal: true

require 'roda'
require 'tilt/erubi'
require 'json'
require_relative 'turbo_broadcast'

module Ai
  module Web
    class App < Roda
      plugin :render, views: File.expand_path('views', __dir__)
      plugin :public, root: File.expand_path('public', __dir__)
      plugin :json
      plugin :halt
      plugin :all_verbs
      plugin :symbol_views
      plugin :streaming

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

            # SSE stream for Turbo Stream updates
            r.on 'stream' do
              r.get do
                channel = "conversation:#{@conversation.id}"
                queue = Thread::Queue.new
                subscriber = TurboBroadcast.subscribe(channel) { |html| queue.push(html) }

                response['Content-Type'] = 'text/event-stream'
                response['Cache-Control'] = 'no-cache'
                response['X-Accel-Buffering'] = 'no'

                stream(loop: true, callback: proc { TurboBroadcast.unsubscribe(channel, subscriber) }) do |out|
                  html = queue.pop
                  out << "data: #{html.gsub("\n", "\ndata: ")}\n\n"
                end
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
                  # Turbo Stream response - append user message and reset form
                  response['Content-Type'] = 'text/vnd.turbo-stream.html'
                  render inline: <<~HTML
                    <turbo-stream action="append" target="messages">
                      <template>
                        #{render('_message', locals: { message: message })}
                      </template>
                    </turbo-stream>
                    <turbo-stream action="replace" target="message-form">
                      <template>
                        <turbo-frame id="message-form">
                          <form action="/conversations/#{@conversation.id}/messages" method="post" class="flex gap-3" data-turbo="true">
                            <input type="hidden" name="turbo" value="1">
                            <textarea
                              name="content"
                              placeholder="Type your message..."
                              rows="3"
                              required
                              autofocus
                              class="textarea textarea-bordered flex-1 text-base"
                            ></textarea>
                            <button type="submit" class="btn btn-primary self-end">Send</button>
                          </form>
                        </turbo-frame>
                      </template>
                    </turbo-stream>
                  HTML
                else
                  r.redirect "/conversations/#{@conversation.id}"
                end
              end
            end
          end
        end

        # AI Pages (individual page by slug)
        r.on 'pages', String do |slug|
          @page = AiPage.published.find_by!(slug: slug)
          view :page_show
        end

        # Jobs & Skills
        r.on 'jobs' do
          r.is do
            r.get do
              @tasks = Ai::ScheduledTask.order(scheduled_for: :desc)
              @skills = SkillRecord.all.order(usage_count: :desc)
              view :jobs_and_skills
            end
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

        # Webhooks
        r.on 'webhooks' do
          r.on 'whatsapp' do
            r.post do
              raw_body = r.body.read

              unless Ai::WhatsApp.verify_signature(raw_body, r.env['HTTP_X_WEBHOOK_SIGNATURE'])
                r.halt 401, { error: 'Invalid signature' }
              end

              payload = JSON.parse(raw_body)
              Ai::WhatsApp.handle_inbound(payload)

              { status: 'ok' }
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
