#!/bin/bash

# n8n Docker Compose Manager (v3.9+)
# Uses multiple compose files approach

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Base compose file
BASE_COMPOSE="docker-compose.yml"

# Help
show_help() {
    echo -e "${BLUE}n8n Docker Compose Manager${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  all         Start all services (PostgreSQL + Redis + n8n)"
    echo "  standalone  Start n8n only (SQLite mode)"
    echo "  postgres    Start n8n + PostgreSQL (no Redis)"
    echo "  down        Stop all services"
    echo "  restart     Restart services"
    echo "  logs        Show logs"
    echo "  ps          Show running containers"
    echo "  backup      Create backup"
    echo "  help        Show this help"
    echo ""
    echo "Options:"
    echo "  -d          Run in detached mode (default)"
    echo "  -f          Follow logs"
    echo ""
    echo "Examples:"
    echo "  $0 all      # Start all services"
    echo "  $0 standalone  # Start n8n with SQLite"
    echo "  $0 logs -f  # Show and follow logs"
}

# Default command
COMMAND=${1:-help}
DETACHED="-d"

# Parse options
shift || true
while [[ $# -gt 0 ]]; do
    case $1 in
        -d)
            DETACHED="-d"
            shift
            ;;
        -f)
            DETACHED=""
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Execute command
case $COMMAND in
    all)
        echo -e "${GREEN}Starting all services (PostgreSQL + Redis + n8n)...${NC}"
        docker compose -f $BASE_COMPOSE \
            -f compose/postgres.yml \
            -f compose/redis.yml \
            -f compose/n8n.yml \
            up $DETACHED
        ;;
        
    standalone)
        echo -e "${GREEN}Starting n8n standalone (SQLite)...${NC}"
        docker compose -f $BASE_COMPOSE \
            -f compose/n8n-standalone.yml \
            up $DETACHED
        ;;
        
    postgres)
        echo -e "${GREEN}Starting n8n + PostgreSQL (no Redis)...${NC}"
        docker compose -f $BASE_COMPOSE \
            -f compose/postgres.yml \
            -f compose/n8n-postgres-only.yml \
            up $DETACHED
        ;;
        
    down)
        echo -e "${YELLOW}Stopping all services...${NC}"
        # Stop all possible combinations
        docker compose -f $BASE_COMPOSE \
            -f compose/postgres.yml \
            -f compose/redis.yml \
            -f compose/n8n.yml \
            down
        docker compose -f $BASE_COMPOSE \
            -f compose/n8n-standalone.yml \
            down 2>/dev/null || true
        ;;
        
    restart)
        echo -e "${YELLOW}Restarting services...${NC}"
        $0 down
        sleep 2
        $0 all
        ;;
        
    logs)
        shift
        docker compose -f $BASE_COMPOSE \
            -f compose/postgres.yml \
            -f compose/redis.yml \
            -f compose/n8n.yml \
            logs $@
        ;;
        
    ps)
        docker compose -f $BASE_COMPOSE \
            -f compose/postgres.yml \
            -f compose/redis.yml \
            -f compose/n8n.yml \
            ps
        ;;
        
    backup)
        echo -e "${BLUE}Creating backup...${NC}"
        mkdir -p backups
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        
        # Backup volumes
        tar -czf backups/n8n-backup-$TIMESTAMP.tar.gz \
            n8n/data \
            postgres/data \
            redis/data 2>/dev/null || true
            
        # Backup PostgreSQL if running
        if docker compose ps postgres | grep -q Up; then
            docker compose exec -T postgres pg_dump -U ${POSTGRES_USER:-n8n} ${POSTGRES_DB:-n8n} \
                > backups/postgres-$TIMESTAMP.sql
        fi
        
        echo -e "${GREEN}Backup completed: backups/*-$TIMESTAMP.*${NC}"
        ;;
        
    help|--help|-h)
        show_help
        ;;
        
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac

# Show status after start
if [[ "$COMMAND" =~ ^(all|standalone|postgres)$ ]]; then
    if [ "$DETACHED" = "-d" ]; then
        echo ""
        echo -e "${GREEN}Services started!${NC}"
        echo "🌐 Access n8n at: http://localhost:${N8N_PORT:-5678}"
        echo "📋 View logs: $0 logs -f"
        echo "🛑 Stop services: $0 down"
    fi
fi