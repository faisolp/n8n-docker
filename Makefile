# Makefile for n8n Docker setup (v3.9+)
.PHONY: help up up-all up-standalone up-postgres down restart logs ps clean backup setup

# Default
help:
	@echo "n8n Docker Management (v3.9+)"
	@echo "----------------------------"
	@echo "Commands:"
	@echo "  make up              - Start all services (default)"
	@echo "  make up-standalone   - Start n8n standalone (SQLite)"
	@echo "  make up-postgres     - Start n8n + PostgreSQL only"
	@echo "  make down            - Stop all services"
	@echo "  make restart         - Restart all services"
	@echo "  make logs            - View logs (all services)"
	@echo "  make logs-n8n        - View n8n logs only"
	@echo "  make ps              - Show running containers"
	@echo "  make backup          - Create backup"
	@echo "  make clean           - Remove containers and volumes"
	@echo "  make setup           - Initial setup"

# Setup
setup:
	@echo "Creating directory structure..."
	@mkdir -p n8n/data n8n/config
	@mkdir -p postgres/data postgres/init
	@mkdir -p redis/data
	@mkdir -p compose
	@mkdir -p backups
	@echo "✓ Setup complete"

# Start services
up: up-all

up-all:
	@echo "Starting all services..."
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/redis.yml \
		-f compose/n8n.yml \
		up -d

up-standalone:
	@echo "Starting n8n standalone..."
	@docker-compose -f docker-compose.yml \
		-f compose/n8n-standalone.yml \
		up -d

up-postgres:
	@echo "Starting n8n + PostgreSQL..."
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/n8n-postgres-only.yml \
		up -d

# Stop services
down:
	@echo "Stopping all services..."
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/redis.yml \
		-f compose/n8n.yml \
		down
	@docker-compose -f docker-compose.yml \
		-f compose/n8n-standalone.yml \
		down 2>/dev/null || true

# Restart
restart:
	@make down
	@sleep 2
	@make up

# Logs
logs:
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/redis.yml \
		-f compose/n8n.yml \
		logs -f

logs-n8n:
	@docker-compose logs -f n8n-app

logs-postgres:
	@docker-compose logs -f n8n-postgres

logs-redis:
	@docker-compose logs -f n8n-redis

# Status
ps:
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/redis.yml \
		-f compose/n8n.yml \
		ps

# Backup
backup:
	@echo "Creating backup..."
	@mkdir -p backups
	@tar -czf backups/n8n-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		n8n/data \
		postgres/data \
		redis/data
	@echo "✓ Backup created"

# Database backup
db-backup:
	@echo "Backing up PostgreSQL..."
	@docker-compose exec -T postgres pg_dump -U $${POSTGRES_USER:-n8n} $${POSTGRES_DB:-n8n} \
		> backups/postgres-$$(date +%Y%m%d-%H%M%S).sql

# Clean
clean:
	@echo "⚠️  This will remove all containers and volumes!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker-compose -f docker-compose.yml \
		-f compose/postgres.yml \
		-f compose/redis.yml \
		-f compose/n8n.yml \
		down -v

# Development helpers
shell-n8n:
	@docker-compose exec n8n-app /bin/sh

shell-postgres:
	@docker-compose exec n8n-postgres /bin/bash

shell-redis:
	@docker-compose exec n8n-redis /bin/sh

# Health check
health:
	@echo "Checking services health..."
	@echo "PostgreSQL:"
	@docker-compose exec postgres pg_isready || echo "PostgreSQL is not ready"
	@echo ""
	@echo "Redis:"
	@docker-compose exec redis redis-cli ping || echo "Redis is not ready"
	@echo ""
	@echo "n8n:"
	@curl -s http://localhost:5678/healthz || echo "n8n is not ready"