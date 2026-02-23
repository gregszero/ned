# frozen_string_literal: true

module Fang
  module Widgets
    class SettingsWidget < BaseWidget
      widget_type 'settings'
      menu_label 'Settings'
      menu_icon "\u2699\uFE0F"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval  = 60

      def render_content
        skills = Fang::SkillRecord.all.order(usage_count: :desc)
        mcp_connections = Fang::McpConnection.all
        config = Fang::Config.all_config

        html = +%(<div class="max-w-5xl mx-auto space-y-6">)
        html << %(<h2 class="text-2xl font-semibold tracking-tight">Settings</h2>)

        # Skills
        html << %(<div class="card"><h3 class="section-heading">Skills (#{skills.count})</h3>)
        if skills.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Name</th><th>Description</th><th>Usage Count</th><th>File</th>)
          html << %(</tr></thead><tbody>)
          skills.each do |skill|
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h skill.name}</td>)
            html << %(<td>#{h skill.description}</td>)
            html << %(<td>#{skill.usage_count}</td>)
            html << %(<td><code>#{h skill.file_path}</code></td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No skills registered yet.</p>)
        end
        html << %(</div>)

        # MCP Connections
        html << %(<div class="card"><h3 class="section-heading">MCP Connections (#{mcp_connections.count})</h3>)
        if mcp_connections.any?
          html << %(<div class="overflow-x-auto"><table><thead><tr>)
          html << %(<th>Name</th><th>Type</th><th>Connection</th><th>Status</th>)
          html << %(</tr></thead><tbody>)
          mcp_connections.each do |conn|
            badge = conn.enabled? ? 'success' : 'error'
            label = conn.enabled? ? 'Enabled' : 'Disabled'
            html << %(<tr>)
            html << %(<td class="font-semibold">#{h conn.name}</td>)
            html << %(<td>#{h conn.transport_type}</td>)
            html << %(<td><code>#{h conn.connection_string}</code></td>)
            html << %(<td><span class="badge #{badge}">#{label}</span></td>)
            html << %(</tr>)
          end
          html << %(</tbody></table></div>)
        else
          html << %(<p class="text-ned-muted-fg">No MCP connections configured.</p>)
        end
        html << %(</div>)

        # WhatsApp Integration
        wa_enabled = Fang::WhatsApp.enabled?
        html << %(<div class="card"><h3 class="section-heading">WhatsApp Integration</h3>)
        html << %(<div class="flex items-center gap-4">)
        html << %(<span class="badge #{wa_enabled ? 'success' : ''}">#{wa_enabled ? 'Enabled' : 'Disabled'}</span>)
        if wa_enabled
          html << %(<a href="http://localhost:3001" target="_blank"><button class="outline sm" type="button">Open GOWA Dashboard</button></a>)
        else
          html << %(<p class="text-sm text-ned-muted-fg">Set <code>WHATSAPP_ENABLED=true</code> to activate.</p>)
        end
        html << %(</div></div>)

        # Configuration
        html << %(<div class="card"><h3 class="section-heading">Configuration</h3>)
        html << %(<div class="overflow-x-auto"><table><thead><tr><th>Key</th><th>Value</th></tr></thead><tbody>)
        html << %(<tr><td>Framework Version</td><td>#{h(config['framework_version'] || '0.1.0')}</td></tr>)
        html << %(<tr><td>Ruby Version</td><td>#{RUBY_VERSION}</td></tr>)
        html << %(<tr><td>Environment</td><td>#{h Fang.env}</td></tr>)
        html << %(<tr><td>Database</td><td>#{ActiveRecord::Base.connection.adapter_name}</td></tr>)
        html << %(<tr><td>Queue Adapter</td><td>#{ActiveJob::Base.queue_adapter.class.name}</td></tr>)
        html << %(</tbody></table></div></div>)

        html << %(</div>)
        html
      end

      def refresh_data!
        new_content = render_content
        if new_content != @component.content
          @component.update!(content: new_content)
          true
        else
          false
        end
      end

      private

      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end
    end
  end
end
