# Deploy OpenFang

Guide for deploying OpenFang to production using Docker Compose or Kamal.

## What this does

Explains how to deploy OpenFang to production:
- Docker Compose (simple, single server)
- Kamal (advanced, multiple servers)
- Environment configuration
- Database setup
- Monitoring and logs

## When to use

Use this skill when you want to:
- Deploy to production
- Set up on a VPS
- Configure for production use
- Deploy updates

## Deployment Options

### Option 1: Docker Compose (Recommended for simple deployments)

**Best for:**
- Single server deployments
- Development/staging environments
- Quick production setup

**Requirements:**
- Linux VPS (Ubuntu 22.04+)
- Docker & Docker Compose installed
- 2GB+ RAM
- Domain name (optional but recommended)

### Option 2: Kamal (Recommended for production)

**Best for:**
- Multiple server deployments
- Zero-downtime deployments
- Production environments

**Requirements:**
- Linux VPS (Ubuntu 22.04+)
- Docker installed
- SSH access
- Domain name
- Ruby installed locally (for kamal CLI)

## Docker Compose Deployment

### Step 1: Prepare Server

```bash
# SSH into your server
ssh user@your-server.com

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get install docker-compose-plugin
```

### Step 2: Clone Repository

```bash
# Clone OpenFang
git clone https://github.com/youruser/OpenFang.git
cd OpenFang
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit with production values
nano .env
```

**Production .env:**
```bash
# Environment
AI_ENV=production
RACK_ENV=production

# Database
DATABASE_URL=postgresql://postgres:STRONG_PASSWORD@db/openfang_production

# API Key (choose one)
CLAUDE_CODE_OAUTH_TOKEN=your-oauth-token
# or
ANTHROPIC_API_KEY=sk-ant-your-key

# Web Server
WEB_HOST=0.0.0.0
WEB_PORT=3000

# Optional: SMTP for email skills
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_FROM=your-email@gmail.com
```

### Step 4: Update docker-compose.yml

```yaml
# Use production configuration
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: openfang_production
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  web:
    build:
      context: .
      dockerfile: Dockerfile.web
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@db/openfang_production
      RAILS_ENV: production
      CLAUDE_CODE_OAUTH_TOKEN: ${CLAUDE_CODE_OAUTH_TOKEN}
    volumes:
      - openfang_storage:/app/storage
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - db
    restart: unless-stopped

volumes:
  postgres_data:
  openfang_storage:
```

### Step 5: Build and Start

```bash
# Build images
docker-compose build

# Start services
docker-compose up -d

# View logs
docker-compose logs -f
```

### Step 6: Initialize Database

```bash
# Run migrations
docker-compose exec web bundle exec rake db:migrate

# Verify
docker-compose exec web bundle exec rake db:version
```

### Step 7: Access Application

Open browser:
```
http://your-server-ip:3000
```

Or configure domain:

```bash
# Install nginx
sudo apt-get install nginx

# Configure reverse proxy
sudo nano /etc/nginx/sites-available/openfang
```

**nginx config:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/openfang /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 8: SSL with Let's Encrypt

```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal is set up automatically
```

## Kamal Deployment

### Step 1: Install Kamal

On your local machine:

```bash
gem install kamal
```

### Step 2: Configure Kamal

Edit `config/deploy.yml`:

```yaml
service: openfang
image: youruser/openfang

servers:
  web:
    hosts:
      - your-server.com
    labels:
      traefik.http.routers.openfang.rule: Host(`your-domain.com`)
      traefik.http.routers.openfang.tls.certresolver: letsencrypt

registry:
  server: ghcr.io
  username: youruser
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    RAILS_ENV: production
  secret:
    - DATABASE_URL
    - CLAUDE_CODE_OAUTH_TOKEN

accessories:
  db:
    image: postgres:16-alpine
    host: your-server.com
    port: 5432
    env:
      clear:
        POSTGRES_DB: openfang_production
      secret:
        - POSTGRES_PASSWORD
    volumes:
      - postgres-data:/var/lib/postgresql/data

traefik:
  options:
    publish:
      - "443:443"
    volume:
      - "/letsencrypt:/letsencrypt"
  args:
    certificatesResolvers.letsencrypt.acme.email: "your-email@example.com"
    certificatesResolvers.letsencrypt.acme.storage: "/letsencrypt/acme.json"
    certificatesResolvers.letsencrypt.acme.httpchallenge: true
    certificatesResolvers.letsencrypt.acme.httpchallenge.entrypoint: web
```

### Step 3: Set Secrets

Create `.kamal/secrets`:

```bash
KAMAL_REGISTRY_PASSWORD=your-github-token
DATABASE_URL=postgresql://postgres:password@openfang-db:5432/openfang_production
CLAUDE_CODE_OAUTH_TOKEN=your-token
POSTGRES_PASSWORD=strong-password
```

### Step 4: Deploy

```bash
# First deployment (sets up everything)
kamal setup

# Future deployments (zero downtime)
kamal deploy

# View logs
kamal app logs

# SSH into container
kamal app exec -i bash

# Rollback
kamal rollback
```

## Environment Variables

### Required

```bash
# Choose ONE authentication method
CLAUDE_CODE_OAUTH_TOKEN=your-oauth-token
# OR
ANTHROPIC_API_KEY=sk-ant-your-key

# Database
DATABASE_URL=postgresql://user:pass@host/database
```

### Optional

```bash
# Environment
AI_ENV=production
RACK_ENV=production

# Server
WEB_HOST=0.0.0.0
WEB_PORT=3000

# MCP
MCP_PORT=9292
MCP_HOST=0.0.0.0

# Logging
LOG_LEVEL=info

# SMTP (for email skills)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-password
SMTP_FROM=your-email@gmail.com
```

## Database Production Setup

### PostgreSQL

```bash
# Create production database
createdb openfang_production

# Or via Docker
docker-compose exec db createdb -U postgres openfang_production

# Run migrations
bundle exec rake db:migrate RAILS_ENV=production
```

### Backups

```bash
# Backup database
docker-compose exec db pg_dump -U postgres openfang_production > backup.sql

# Restore database
docker-compose exec -T db psql -U postgres openfang_production < backup.sql

# Automated backups (cron)
0 2 * * * cd /path/to/OpenFang && docker-compose exec -T db pg_dump -U postgres openfang_production > backups/backup-$(date +\%Y\%m\%d).sql
```

## Monitoring

### Health Checks

```bash
# Check service health
curl http://your-domain.com/health

# Expected response
{"status":"ok","timestamp":"2026-02-16T14:00:00Z"}
```

### Logs

**Docker Compose:**
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web

# Last 100 lines
docker-compose logs --tail=100 web
```

**Kamal:**
```bash
# Application logs
kamal app logs

# Follow logs
kamal app logs -f

# Container logs
kamal app logs --tail 100
```

### Metrics

Monitor:
- CPU usage: `docker stats`
- Memory usage: `docker stats`
- Disk usage: `df -h`
- Database size: `du -h storage/`

## Updates

### Docker Compose

```bash
# Pull latest code
git pull origin master

# Rebuild and restart
docker-compose build
docker-compose up -d

# Run new migrations
docker-compose exec web bundle exec rake db:migrate
```

### Kamal

```bash
# Pull latest code
git pull origin master

# Deploy (zero downtime)
kamal deploy
```

## Scaling

### Horizontal Scaling (Multiple Servers)

Update `config/deploy.yml`:

```yaml
servers:
  web:
    hosts:
      - server1.com
      - server2.com
      - server3.com
```

### Vertical Scaling (More Resources)

Update docker-compose.yml:

```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

## Troubleshooting

**"Container exits immediately"**
```bash
# Check logs
docker-compose logs web

# Common issues:
# - Missing DATABASE_URL
# - Missing API key
# - Database not ready
```

**"Cannot connect to database"**
```bash
# Check database container
docker-compose ps db

# Check connection
docker-compose exec web psql $DATABASE_URL -c "SELECT 1"
```

**"Port already in use"**
```bash
# Find process using port
sudo lsof -i :3000

# Kill process or change port in docker-compose.yml
```

**"Out of disk space"**
```bash
# Clean Docker
docker system prune -a

# Clean old images
docker images prune

# Check disk usage
df -h
```

**"Agent container fails to spawn"**
```bash
# Check Docker socket
ls -la /var/run/docker.sock

# Fix permissions
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group
sudo usermod -aG docker $USER
```

## Security

### Firewall

```bash
# Install ufw
sudo apt-get install ufw

# Allow SSH
sudo ufw allow 22

# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Enable firewall
sudo ufw enable
```

### Secrets Management

Never commit secrets! Use:
- Environment variables
- `.env` files (gitignored)
- Secret management services
- Kamal secrets

### Updates

```bash
# Keep system updated
sudo apt-get update && sudo apt-get upgrade

# Update Docker images
docker-compose pull
docker-compose up -d
```

## Backup Strategy

1. **Database**: Daily backups to S3/remote storage
2. **Storage**: Backup `storage/` directory
3. **Code**: Git repository (GitHub + entire.io)
4. **Environment**: Keep `.env` backup securely

## Documentation

- Docker Compose: https://docs.docker.com/compose/
- Kamal: https://kamal-deploy.org/
- Configuration: `config/deploy.yml`
- Environment: `.env.example`

**Deployment ready!** Choose Docker Compose or Kamal and deploy. 🚀
