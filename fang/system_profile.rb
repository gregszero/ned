# frozen_string_literal: true

module Fang
  module SystemProfile
    class << self
      attr_reader :profile, :detected_at

      def detect!
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @profile = {
          os: detect_os,
          hostname: detect_hostname,
          hardware: detect_hardware,
          disk: detect_disk,
          network: detect_network,
          cli_tools: detect_cli_tools,
          services: detect_services,
          user: detect_user,
          environment: detect_environment
        }
        @detected_at = Time.now
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(2)
        Fang.logger.info "System profile detected in #{elapsed}s"
        @profile
      end

      def refresh!
        detect!
      end

      def to_h
        { detected_at: @detected_at&.iso8601, profile: @profile }
      end

      private

      def run(cmd)
        `#{cmd} 2>/dev/null`.strip.presence
      rescue StandardError
        nil
      end

      # --- OS ---

      def detect_os
        os_release = parse_os_release
        {
          distribution: os_release['PRETTY_NAME'] || os_release['NAME'],
          version: os_release['VERSION_ID'],
          id: os_release['ID'],
          kernel: run('uname -r'),
          arch: run('uname -m'),
          uptime: parse_uptime
        }
      end

      def parse_os_release
        path = '/etc/os-release'
        return {} unless File.exist?(path)

        File.readlines(path).each_with_object({}) do |line, hash|
          key, value = line.strip.split('=', 2)
          hash[key] = value&.delete('"') if key && value
        end
      rescue StandardError
        {}
      end

      def parse_uptime
        raw = File.read('/proc/uptime').split.first.to_f
        days = (raw / 86400).to_i
        hours = ((raw % 86400) / 3600).to_i
        mins = ((raw % 3600) / 60).to_i
        { seconds: raw.to_i, human: "#{days}d #{hours}h #{mins}m" }
      rescue StandardError
        nil
      end

      # --- Hostname ---

      def detect_hostname
        {
          hostname: run('hostname -s'),
          fqdn: run('hostname -f')
        }
      end

      # --- Hardware ---

      def detect_hardware
        {
          cpu: detect_cpu,
          memory: detect_memory
        }
      end

      def detect_cpu
        model = nil
        cores = 0
        if File.exist?('/proc/cpuinfo')
          lines = File.readlines('/proc/cpuinfo')
          model_line = lines.find { |l| l.start_with?('model name') }
          model = model_line&.split(':')&.last&.strip
          cores = lines.count { |l| l.start_with?('processor') }
        end
        { model: model, cores: cores }
      rescue StandardError
        { model: nil, cores: nil }
      end

      def detect_memory
        if File.exist?('/proc/meminfo')
          lines = File.readlines('/proc/meminfo')
          total_kb = lines.find { |l| l.start_with?('MemTotal') }&.scan(/\d+/)&.first&.to_i
          avail_kb = lines.find { |l| l.start_with?('MemAvailable') }&.scan(/\d+/)&.first&.to_i
          {
            total_mb: total_kb ? (total_kb / 1024.0).round : nil,
            available_mb: avail_kb ? (avail_kb / 1024.0).round : nil
          }
        else
          { total_mb: nil, available_mb: nil }
        end
      rescue StandardError
        { total_mb: nil, available_mb: nil }
      end

      # --- Disk ---

      def detect_disk
        raw = run("df -h --output=target,size,used,avail,pcent -x tmpfs -x devtmpfs -x squashfs")
        return [] unless raw

        lines = raw.lines.drop(1) # skip header
        lines.map do |line|
          parts = line.split
          next unless parts.length >= 5
          {
            mount: parts[0],
            size: parts[1],
            used: parts[2],
            available: parts[3],
            use_percent: parts[4]
          }
        end.compact
      end

      # --- Network ---

      def detect_network
        {
          interfaces: detect_interfaces,
          public_ip: run("curl -s ifconfig.me --max-time 2")
        }
      end

      def detect_interfaces
        raw = run("ip -brief addr show")
        return [] unless raw

        raw.lines.filter_map do |line|
          parts = line.split
          next if parts.length < 3
          next if parts[0] == 'lo'
          {
            name: parts[0],
            state: parts[1].downcase,
            addresses: parts[2..].map { |a| a.split('/').first }
          }
        end
      end

      # --- CLI Tools ---

      TOOL_LIST = %w[
        git ruby python3 python node npm bun deno
        gcc g++ make cmake
        podman kubectl helm
        curl wget rsync ssh scp
        vim nvim nano emacs
        tmux screen
        htop btop
        jq yq
        zip unzip tar gzip
        sqlite3 psql mysql redis-cli
        ffmpeg imagemagick
        aws gcloud az
        terraform ansible
        go rustc cargo java javac
        claude
        systemctl journalctl
        ip ss netstat
        rg fd bat eza
      ].freeze

      def detect_cli_tools
        tools = {}
        TOOL_LIST.each do |tool|
          path = run("which #{tool}")
          next unless path
          version = extract_version(tool)
          tools[tool] = { path: path, version: version }
        end
        tools
      end

      def extract_version(tool)
        # Try common version flags
        result = run("#{tool} --version") || run("#{tool} -V") || run("#{tool} -v")
        return nil unless result
        # Extract first version-like string
        result.lines.first&.strip&.slice(/\d+\.\d+[\.\d]*/)
      end

      # --- Services ---

      def detect_services
        raw = run("systemctl list-units --type=service --state=running --no-pager --no-legend")
        return [] unless raw

        raw.lines.filter_map do |line|
          parts = line.strip.split
          next unless parts.length >= 4
          unit = parts[0]
          next if unit.start_with?('user@', 'init-', 'systemd-')
          unit.delete_suffix('.service')
        end
      end

      # --- User ---

      def detect_user
        {
          username: run('whoami'),
          groups: run('groups')&.split,
          shell: ENV['SHELL'],
          home: ENV['HOME'],
          sudo: test_sudo
        }
      end

      def test_sudo
        system('sudo -n true 2>/dev/null')
      end

      # --- Environment ---

      def detect_environment
        {
          path_dirs: ENV['PATH']&.split(':'),
          locale: ENV['LANG'] || ENV['LC_ALL'],
          display_server: ENV['WAYLAND_DISPLAY'] ? 'wayland' : (ENV['DISPLAY'] ? 'x11' : 'headless'),
          ssh_session: ENV.key?('SSH_CONNECTION'),
          term: ENV['TERM'],
          editor: ENV['EDITOR'] || ENV['VISUAL']
        }
      end
    end
  end
end
