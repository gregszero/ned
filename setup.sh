#!/bin/bash
set -e

echo "Setting up OpenFang..."
echo ""

# 1. Check dependencies
echo "Checking dependencies..."
command -v ruby >/dev/null || { echo "❌ Ruby not found. Please install Ruby 3.3+"; exit 1; }
command -v claude >/dev/null || echo "⚠️  Claude CLI not found. Install it for agent execution."
command -v git >/dev/null || { echo "❌ Git not found. Please install Git"; exit 1; }
echo "✅ All dependencies found"
echo ""

# Check/install Computer Use Agent dependencies
echo "Checking Computer Use Agent dependencies..."
CUA_DEPS_PACMAN="xorg-server-xvfb xorg-xset xdotool scrot openbox"
CUA_DEPS_APT="xvfb x11-xserver-utils xdotool scrot openbox firefox-esr"
if command -v pacman >/dev/null; then
  MISSING=""
  for pkg in $CUA_DEPS_PACMAN; do
    pacman -Q "$pkg" &>/dev/null || MISSING="$MISSING $pkg"
  done
  if [ -n "$MISSING" ]; then
    echo "Installing CUA dependencies:$MISSING"
    sudo pacman -S --noconfirm $MISSING
  fi
elif command -v apt-get >/dev/null; then
  sudo apt-get install -y $CUA_DEPS_APT
fi
echo "✅ Computer Use Agent dependencies ready"
echo ""

# 2. Check Ruby version
RUBY_VERSION=$(ruby -e 'puts RUBY_VERSION')
echo "Ruby version: $RUBY_VERSION"

# 3. Install gems
echo ""
echo "Installing Ruby gems..."
bundle install
echo "✅ Gems installed"
echo ""

# 4. Setup environment
if [ ! -f .env ]; then
  echo "Creating .env file from template..."
  cp .env.example .env
  echo "⚠️  Please edit .env and add your CLAUDE_CODE_OAUTH_TOKEN or ANTHROPIC_API_KEY"
fi
echo ""

# 5. Create storage directories
echo "Creating storage directories..."
mkdir -p storage/data storage/sessions workspace/migrations
echo "✅ Storage directories created"
echo ""

# 6. Setup database
echo "Setting up database..."
bundle exec rake db:migrate
echo "✅ Database setup complete"
echo ""

# 7. Detect system capabilities
echo "Detecting system capabilities..."
bundle exec ruby -e "
  require_relative 'fang/bootstrap'
  profile = Fang::SystemProfile.profile
  puts \"  OS: #{profile.dig(:os, :distribution) || 'unknown'}\"
  puts \"  CPU: #{profile.dig(:hardware, :cpu, :model)} (#{profile.dig(:hardware, :cpu, :cores)} cores)\"
  puts \"  RAM: #{profile.dig(:hardware, :memory, :total_mb)}MB\"
  tool_names = profile[:cli_tools]&.keys || []
  puts \"  Tools (#{tool_names.size}): #{tool_names.first(15).join(', ')}#{'...' if tool_names.size > 15}\"
  missing = %w[git ruby curl claude].reject { |t| tool_names.include?(t) }
  puts \"  Missing recommended: #{missing.join(', ')}\" if missing.any?
"
echo "✅ System profile cached"
echo ""

# 8. Initialize git if not already
if [ ! -d .git ]; then
  echo "Initializing git repository..."
  git init
  git add .
  git commit -m "Initial commit: OpenFang framework"
  echo "✅ Git repository initialized"
else
  echo "Git repository already initialized"
fi
echo ""

# 9. Setup git remotes (optional)
echo "Git remote configuration:"
echo "  Primary: GitHub (git push origin)"
echo "  Mirror: entire.io (git push entire)"
echo ""
echo "To configure remotes, run:"
echo "  git remote add origin https://github.com/yourusername/openfang.git"
echo "  git remote add entire https://entire.io/yourusername/openfang.git"
echo ""

# 10. Success message
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env and add your API credentials"
echo "  2. Start the web server: ./openfang.rb server"
echo "  3. Open http://localhost:3000 in your browser"
echo "  4. Create a conversation and start chatting!"
echo ""
echo "For help: ./openfang.rb help"
echo ""
echo "📚 Documentation:"
echo "  - README.md - Quick start guide"
echo "  - docs/MCP_ARCHITECTURE.md - MCP design philosophy"
echo "  - IMPLEMENTATION_STATUS.md - Implementation progress"
