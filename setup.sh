#!/bin/bash
set -e

echo "🧙 Setting up Ned..."
echo ""

# 1. Check dependencies
echo "Checking dependencies..."
command -v ruby >/dev/null || { echo "❌ Ruby not found. Please install Ruby 3.3+"; exit 1; }
command -v docker >/dev/null || { echo "❌ Docker not found. Please install Docker"; exit 1; }
command -v git >/dev/null || { echo "❌ Git not found. Please install Git"; exit 1; }
echo "✅ All dependencies found"
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

# 7. Build agent container
echo "Building agent container..."
if [ -f container/Dockerfile ]; then
  docker build -f container/Dockerfile -t ai-rb-agent .
  echo "✅ Container image built"
else
  echo "⚠️  container/Dockerfile not found - skipping container build"
  echo "   Run 'docker build -f container/Dockerfile -t ai-rb-agent .' later"
fi
echo ""

# 8. Initialize git if not already
if [ ! -d .git ]; then
  echo "Initializing git repository..."
  git init
  git add .
  git commit -m "Initial commit: ai.rb framework"
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
echo "  git remote add origin https://github.com/yourusername/ai.rb.git"
echo "  git remote add entire https://entire.io/yourusername/ai.rb.git"
echo ""

# 10. Success message
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env and add your API credentials"
echo "  2. Start the web server: ./ai.rb server"
echo "  3. Open http://localhost:3000 in your browser"
echo "  4. Create a conversation and start chatting!"
echo ""
echo "For help: ./ai.rb help"
echo ""
echo "📚 Documentation:"
echo "  - README.md - Quick start guide"
echo "  - docs/MCP_ARCHITECTURE.md - MCP design philosophy"
echo "  - IMPLEMENTATION_STATUS.md - Implementation progress"
