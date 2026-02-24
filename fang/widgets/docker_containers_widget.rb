# frozen_string_literal: true

module Fang
  module Widgets
    class DockerContainersWidget < BaseWidget
      widget_type 'docker_containers'
      menu_label 'Docker Containers'
      menu_icon "\u{1F433}"
      menu_category 'System'

      def self.refreshable?     = true
      def self.refresh_interval = 30
      def self.header_title     = 'Docker Containers'
      def self.header_color     = '#2496ed'

      def render_content
        show_all = @metadata['show_all']
        cmd = show_all ? 'docker ps -a' : 'docker ps'
        cmd += " --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"

        output = IO.popen(cmd, err: [:child, :out], &:read)
        unless $?.success?
          return %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">Docker not available</div>)
        end

        lines = output.strip.split("\n").reject(&:empty?)
        if lines.empty?
          return %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">No containers running</div>)
        end

        render_table(lines)
      rescue => e
        Fang.logger.error "Docker containers widget error: #{e.message}"
        %(<div class="p-4 text-center text-sm" style="color:var(--muted-foreground)">Docker not available</div>)
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

      def render_table(lines)
        html = +%(<div class="flex flex-col gap-2 p-3">)
        html << %(<div class="overflow-x-auto">)
        html << %(<table><thead><tr>)
        html << %(<th>ID</th><th>Name</th><th>Image</th><th>Status</th><th>Ports</th>)
        html << %(</tr></thead><tbody>)

        lines.each do |line|
          id, name, image, status, ports = line.split("\t", 5)
          ports = ports.to_s.strip
          ports = "\u2014" if ports.empty?

          badge_class = status.to_s.match?(/\bUp\b/i) ? 'success' : 'error'

          html << %(<tr>)
          html << %(<td><code class="text-xs">#{h id}</code></td>)
          html << %(<td class="font-semibold">#{h name}</td>)
          html << %(<td class="text-xs" style="color:var(--muted-foreground)">#{h image}</td>)
          html << %(<td><span class="badge #{badge_class}">#{h status}</span></td>)
          html << %(<td class="text-xs" style="color:var(--muted-foreground)">#{h ports}</td>)
          html << %(</tr>)
        end

        html << %(</tbody></table></div>)
        html << %(</div>)
        html
      end
    end
  end
end
