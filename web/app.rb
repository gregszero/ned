# frozen_string_literal: true

require 'roda'
require 'tilt/erubi'
require 'json'
require 'pagy'
require_relative 'turbo_broadcast'
require_relative 'view_helpers'

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

      include Pagy::Method

      # Pagy::Method expects a `params` method
      def params = request.params

      # Make models and helpers available in views
      plugin :render_locals, locals: {
        Conversation: Ai::Conversation,
        Message: Ai::Message,
        SkillRecord: Ai::SkillRecord,
        Config: Ai::Config,
        Notification: Ai::Notification
      }

      include ViewHelpers

      def turbo_frame_request?
        env['HTTP_TURBO_FRAME'] == 'canvas-content'
      end

      def render_canvas_or_layout(template)
        if turbo_frame_request?
          content = render(template)
          "<turbo-frame id=\"canvas-content\"><main class=\"page-content max-w-7xl mx-auto p-6 w-full\">#{content}</main></turbo-frame>"
        else
          view template
        end
      end

      def sse_stream(channel)
        queue = Thread::Queue.new
        subscriber = TurboBroadcast.subscribe(channel) { |html| queue.push(html) }

        Ai.logger.info "[SSE] Connection opened for #{channel}"

        response['Content-Type'] = 'text/event-stream'
        response['Cache-Control'] = 'no-cache'
        response['X-Accel-Buffering'] = 'no'

        stream(loop: true, callback: proc {
          Ai.logger.info "[SSE] Connection closed for #{channel}"
          TurboBroadcast.unsubscribe(channel, subscriber)
        }) do |out|
          html = queue.pop(timeout: 30)
          if html
            Ai.logger.info "[SSE] Sending event to #{channel} (#{html.length} bytes)"
            out << "data: #{html.gsub("\n", "\ndata: ")}\n\n"
          else
            out << ": heartbeat\n\n"
          end
        end
      end

      route do |r|
        r.public

        # Root — redirect to most recent canvas or show home
        r.root do
          recent = AiPage.published.recent.first
          if recent
            r.redirect "/#{recent.slug}"
          else
            render_canvas_or_layout(:home)
          end
        end

        # Conversations routes (kept for panel loading and messages)
        r.on 'conversations' do
          # Individual conversation
          r.on Integer do |id|
            @conversation = Conversation.find(id)

            r.is do
              r.get do
                @messages = @conversation.messages.chronological
                render_canvas_or_layout(:conversation_show)
              end
            end

            # Chat panel fragment (no layout)
            r.on 'panel' do
              r.get do
                @messages = @conversation.messages.chronological
                render(:conversation_panel)
              end
            end

            # Canvas content
            r.on 'canvas' do
              r.get do
                response['Content-Type'] = 'text/html'
                if @conversation.ai_page
                  @conversation.ai_page.content.presence || '<div class="p-6 text-center text-ned-muted-fg text-sm">Canvas is empty</div>'
                else
                  '<div class="p-6 text-center text-ned-muted-fg text-sm">Canvas is empty</div>'
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

                message = @conversation.add_message(
                  role: 'user',
                  content: content
                )

                Ai::Jobs::AgentExecutorJob.perform_later(message.id)

                if r.params['turbo']
                  message_html = render_message_html(message)

                  response['Content-Type'] = 'text/vnd.turbo-stream.html'
                  turbo_stream('append', "messages-#{@conversation.id}") { message_html } +
                  turbo_stream('replace', 'message-form') do
                    <<~HTML
                      <turbo-frame id="message-form">
                        <form action="/conversations/#{@conversation.id}/messages" method="post" class="flex gap-3" data-turbo="true">
                          <input type="hidden" name="turbo" value="1">
                          <textarea
                            name="content"
                            placeholder="Type your message..."
                            rows="3"
                            required
                            autofocus
                            class="flex-1"
                          ></textarea>
                          <button type="submit" class="self-end">Send</button>
                        </form>
                      </turbo-frame>
                    HTML
                  end
                else
                  response.status = 200
                  { status: 'ok' }
                end
              end
            end
          end
        end

        # AI Pages (individual page by slug)
        r.on 'pages', String do |slug|
          @page = AiPage.published.find_by!(slug: slug)
          render_canvas_or_layout(:page_show)
        end

        # Notifications
        r.on 'notifications' do
          # SSE stream
          r.on 'stream' do
            r.get do
              sse_stream('notifications')
            end
          end

          # Mark read
          r.on Integer, 'read' do |id|
            r.post do
              notification = Ai::Notification.find(id)
              notification.mark_read!
              { status: 'ok' }
            end
          end

          # Start chat from notification — returns JSON for JS-driven canvas opening
          r.on Integer, 'chat' do |id|
            r.post do
              notification = Ai::Notification.find(id)
              conversation = notification.start_conversation!
              notification.mark_read!
              page = notification.ai_page

              {
                conversation_id: conversation.id,
                title: conversation.title,
                slug: conversation.slug,
                page_id: page.id,
                page_title: page.title,
                page_slug: page.slug
              }
            end
          end
        end

        # Jobs & Skills — canvas page
        r.on 'jobs' do
          @page = AiPage.find_by(slug: 'jobs')
          r.on String do |chat_slug|
            @conversation = @page&.conversations&.find_by(slug: chat_slug)
            render_canvas_or_layout(:canvas_view)
          end
          r.is do
            render_canvas_or_layout(:canvas_view)
          end
        end

        # Heartbeats — canvas page
        r.on 'heartbeats' do
          @page = AiPage.find_by(slug: 'heartbeats')
          r.on String do |chat_slug|
            @conversation = @page&.conversations&.find_by(slug: chat_slug)
            render_canvas_or_layout(:canvas_view)
          end
          r.is do
            render_canvas_or_layout(:canvas_view)
          end
        end

        # Settings — canvas page
        r.on 'settings' do
          @page = AiPage.find_by(slug: 'settings')
          r.on String do |chat_slug|
            @conversation = @page&.conversations&.find_by(slug: chat_slug)
            render_canvas_or_layout(:canvas_view)
          end
          r.is do
            render_canvas_or_layout(:canvas_view)
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
          # Data table pagination endpoint
          r.on 'tables', Integer, 'rows' do |component_id|
            r.get do
              component = Ai::CanvasComponent.find(component_id)
              widget = Ai::Widgets::DataTableWidget.new(component)

              page     = (r.params['page'] || 1).to_i
              sort_col = r.params['sort']
              sort_dir = r.params['dir']

              # Build filters from query params like filter[status]=pending
              filters = []
              (r.params['filter'] || {}).each do |col, val|
                filters << { 'column' => col, 'operator' => '=', 'value' => val }
              end
              filters = nil if filters.empty?

              rows_html, has_more = widget.render_page(page: page, sort_col: sort_col, sort_dir: sort_dir, filters: filters)
              cid = component.id

              sentinel = ''
              if has_more
                next_page = page + 1
                src = "/api/tables/#{cid}/rows?page=#{next_page}"
                src += "&sort=#{Rack::Utils.escape(sort_col)}" if sort_col
                src += "&dir=#{Rack::Utils.escape(sort_dir)}" if sort_dir
                (r.params['filter'] || {}).each { |k, v| src += "&filter[#{Rack::Utils.escape(k)}]=#{Rack::Utils.escape(v)}" }
                sentinel = %(<tr class="data-table-next-page"><td colspan="999"><turbo-frame id="data-table-page-#{cid}-#{next_page}" loading="lazy" src="#{src}"></turbo-frame></td></tr>)
              end

              response['Content-Type'] = 'text/html'

              # When frame=body, wrap in the body frame (used for sort reloads)
              frame_id = if r.params['frame'] == 'body'
                           "data-table-body-#{cid}"
                         else
                           "data-table-page-#{cid}-#{page}"
                         end

              <<~HTML
                <turbo-frame id="#{frame_id}" tag="tbody">
                  #{rows_html}
                  #{sentinel}
                </turbo-frame>
              HTML
            end
          end
          r.on 'notifications' do
            r.is do
              r.get do
                pagy, notifications = pagy(Ai::Notification.recent, limit: (r.params['limit'] || 5).to_i.clamp(1, 20), page: (r.params['page'] || 1).to_i)

                html = notifications.map { |n| render_notification_card_html(n) }.join

                { html: html, count: notifications.size, has_more: !pagy.next.nil?, page: pagy.page, pages: pagy.last }
              end
            end
          end

          r.on 'conversations' do
            r.is do
              r.get do
                conversations = Conversation.recent.limit(20).map do |c|
                  {
                    id: c.id,
                    title: c.title,
                    slug: c.slug,
                    source: c.source,
                    ai_page_id: c.ai_page_id,
                    message_count: c.messages.count,
                    last_message_at: c.last_message_at
                  }
                end
                { conversations: conversations }
              end

              r.post do
                ai_page_id = r.params['ai_page_id']
                title = r.params['title'].to_s.strip
                title = 'New Conversation' if title.empty?
                conversation = Conversation.create!(
                  title: title,
                  source: 'web',
                  ai_page_id: ai_page_id
                )
                { id: conversation.id, title: conversation.title, slug: conversation.slug, ai_page_id: conversation.ai_page_id }
              end
            end
          end

          # Create canvas (AiPage + Conversation together)
          r.on 'canvases' do
            r.post do
              page = AiPage.create!(
                title: r.params['title'] || 'New Canvas',
                content: '',
                status: 'published',
                published_at: Time.current
              )
              conversation = Conversation.create!(
                title: page.title,
                source: 'web',
                ai_page: page
              )
              { id: conversation.id, title: conversation.title, ai_page_id: page.id, page_slug: page.slug, conv_slug: conversation.slug }
            end
          end

          # Action system — execute actions from widget buttons
          r.on 'actions' do
            r.post do
              body = JSON.parse(r.body.read) rescue r.params
              action_type = body['action_type']

              result = case action_type
              when 'run_skill'
                skill = Ai::SkillRecord.find_by(name: body['skill_name'])
                unless skill
                  r.halt 404, { success: false, error: "Skill '#{body['skill_name']}' not found" }
                end
                params = (body['params'] || {}).transform_keys(&:to_sym)
                output = skill.load_and_execute(**params)
                skill.increment_usage!
                { success: true, result: output }

              when 'run_code'
                code = body['code'] || body['ruby_code']
                unless code
                  r.halt 400, { success: false, error: 'Missing code parameter' }
                end
                ctx = Object.new
                Ai.constants.map { |c| Ai.const_get(c) }
                  .select { |c| c.is_a?(Class) && c < ActiveRecord::Base }
                  .each { |model| ctx.define_singleton_method(model.name.demodulize.to_sym) { model } }
                output = ctx.instance_eval(code)
                { success: true, result: output.inspect }

              when 'send_message'
                conv = Ai::Conversation.find(body['conversation_id'])
                message = conv.add_message(role: 'user', content: body['content'])
                Ai::Jobs::AgentExecutorJob.perform_later(message.id)
                { success: true, message_id: message.id }

              when 'refresh_component'
                component = Ai::CanvasComponent.find(body['component_id'])
                widget_class = Ai::Widgets::BaseWidget.for_type(component.component_type)
                if widget_class
                  widget = widget_class.new(component)
                  if widget.refresh_data!
                    turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                            "<template>#{widget.render_component_html}</template></turbo-stream>"
                    TurboBroadcast.broadcast("canvas:#{component.ai_page_id}", turbo)
                  end
                  { success: true, refreshed: true }
                else
                  { success: false, error: 'Unknown widget type' }
                end

              when 'toggle_heartbeat'
                heartbeat = Ai::Heartbeat.find(body['heartbeat_id'])
                if heartbeat.enabled?
                  heartbeat.update!(enabled: false, status: 'paused')
                else
                  heartbeat.update!(enabled: true, status: 'active')
                end
                { success: true, enabled: heartbeat.enabled?, status: heartbeat.status }

              else
                r.halt 400, { success: false, error: "Unknown action_type: #{action_type}" }
              end

              result
            rescue => e
              Ai.logger.error "Action failed: #{e.message}"
              { success: false, error: e.message }
            end
          end

          # Heartbeat toggle
          r.on 'heartbeats', Integer, 'toggle' do |hb_id|
            r.post do
              heartbeat = Ai::Heartbeat.find(hb_id)
              if heartbeat.enabled?
                heartbeat.update!(enabled: false, status: 'paused')
              else
                heartbeat.update!(enabled: true, status: 'active')
              end

              # Trigger widget refresh
              page = heartbeat.ai_page || AiPage.find_by(slug: 'heartbeats')
              if page
                component = page.canvas_components.find_by(component_type: 'heartbeat_monitor')
                if component
                  widget_class = Ai::Widgets::BaseWidget.for_type('heartbeat_monitor')
                  if widget_class
                    widget = widget_class.new(component)
                    if widget.refresh_data!
                      turbo = "<turbo-stream action=\"replace\" target=\"canvas-component-#{component.id}\">" \
                              "<template>#{widget.render_component_html}</template></turbo-stream>"
                      TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
                    end
                  end
                end
              end

              { success: true, enabled: heartbeat.enabled?, status: heartbeat.status }
            end
          end

          # Widget type registry
          r.on 'widget_types' do
            r.get do
              types = Ai::Widgets::BaseWidget.registry.map do |type, klass|
                { type: type, label: klass.menu_label_text || type.tr('_', ' ').capitalize,
                  icon: klass.menu_icon_text, defaults: klass.default_metadata }
              end
              { widget_types: types }
            end
          end

          # Page canvas content by page ID
          r.on 'pages', Integer do |page_id|
            page = AiPage.find(page_id)

            # Canvas SSE stream — one per canvas
            r.on 'stream' do
              r.get do
                sse_stream("canvas:#{page.id}")
              end
            end

            r.on 'canvas' do
              r.get do
                components = page.canvas_components.ordered.map do |comp|
                  # Auto-render widget content if stored content is blank
                  if comp.content.blank?
                    rendered = comp.render_content_html
                    comp.update_column(:content, rendered) if rendered.present?
                  end
                  comp.as_canvas_json
                end
                {
                  components: components,
                  canvas_state: page.canvas_state || {}
                }
              end
            end

            r.on 'components' do
              r.is do
                r.post do
                  body = JSON.parse(r.body.read) rescue r.params
                  comp_type = body['component_type'] || 'card'
                  metadata = body['metadata'] || {}

                  # Merge widget default metadata
                  widget_class = Ai::Widgets::BaseWidget.for_type(comp_type)
                  metadata = widget_class.default_metadata.merge(metadata) if widget_class

                  component = page.canvas_components.create!(
                    component_type: comp_type,
                    content: body['content'] || '',
                    x: body['x']&.to_f || 0,
                    y: body['y']&.to_f || 0,
                    width: body['width']&.to_f || 320,
                    height: body['height']&.to_f,
                    z_index: body['z_index']&.to_i || 0,
                    metadata: metadata
                  )

                  # Auto-render content from widget if content is blank
                  if component.content.blank?
                    rendered = component.render_content_html
                    component.update_column(:content, rendered) if rendered.present?
                  end

                  # Broadcast via canvas channel
                  html = component.render_html
                  turbo = "<turbo-stream action=\"append\" target=\"canvas-components-#{page.id}\"><template>#{html}</template></turbo-stream>"
                  TurboBroadcast.broadcast("canvas:#{page.id}", turbo)

                  component.as_canvas_json
                end
              end

              r.on Integer do |component_id|
                component = page.canvas_components.find(component_id)

                r.get do
                  component.as_canvas_json
                end

                r.patch do
                  body = begin; JSON.parse(r.body.read); rescue; r.params; end
                  updates = {}
                  %w[x y width height z_index].each do |attr|
                    updates[attr] = (body[attr] || r.params[attr]).to_f if body[attr] || r.params[attr]
                  end
                  updates[:content] = body['content'] if body.key?('content')
                  if body.key?('metadata')
                    updates[:metadata] = (component.metadata || {}).deep_merge(body['metadata'])
                  end
                  component.update!(updates) if updates.any?
                  component.as_canvas_json
                end

                r.delete do
                  turbo = "<turbo-stream action=\"remove\" target=\"canvas-component-#{component.id}\"></turbo-stream>"
                  TurboBroadcast.broadcast("canvas:#{page.id}", turbo)
                  component.destroy!
                  { success: true }
                end
              end
            end
          end
        end

        # Canvas URL: /:canvas_slug or /:canvas_slug/:chat_slug
        # This MUST be last — it's a catch-all for slug-based routes
        r.on String do |canvas_slug|
          @page = AiPage.find_by(slug: canvas_slug)
          next unless @page

          r.on String do |chat_slug|
            @conversation = @page.conversations.find_by(slug: chat_slug)
            render_canvas_or_layout(:canvas_view)
          end

          r.is do
            render_canvas_or_layout(:canvas_view)
          end
        end
      end
    end
  end
end
