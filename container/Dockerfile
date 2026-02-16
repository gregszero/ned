# AI Agent Container - Claude Code SDK
FROM ruby:3.3-alpine

LABEL maintainer="ai.rb"
LABEL description="Ruby AI agent container with Claude Code SDK"

# Install system dependencies
RUN apk add --no-cache \
    bash \
    git \
    curl \
    nodejs \
    npm \
    build-base \
    postgresql-dev \
    sqlite-dev \
    tzdata

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Install common Ruby gems
RUN gem install \
    activesupport \
    activerecord \
    httparty \
    nokogiri \
    json \
    --no-document

# Create working directories
WORKDIR /workspace

# Create session directory
RUN mkdir -p /session

# Set environment variables
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# Default command (will be overridden at runtime)
CMD ["sleep", "infinity"]
