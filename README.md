# n8n Docker Setup

โปรเจ็คนี้เป็นการจัดการ n8n และ services ที่เกี่ยวข้องด้วย Docker Compose v3.9+ แบบ modular โดยใช้ multiple compose files

## Requirements

- Docker Engine 20.10+
- Docker Compose 1.29+ (รองรับ compose file v3.9)
- Git (optional)

## โครงสร้างโปรเจ็ค

```
n8n-docker/
├── docker-compose.yml           # Base configuration (networks, volumes)
├── .env                         # Environment variables
├── start.sh                     # Management script
├── Makefile                     # Make commands
│
├── compose/                     # Service definitions
│   ├── postgres.yml            # PostgreSQL service
│   ├── redis.yml               # Redis service
│   ├── n8n.yml                 # n8n full stack
│   ├── n8n-standalone.yml      # n8n standalone (SQLite)
│   └── n8n-postgres-only.yml   # n8n + PostgreSQL only
│
├── n8n/                        # n8n data and configs
│   ├── data/                   # Workflow data, SQLite DB
│   └── config/                 # Custom configurations
│
├── postgres/                   # PostgreSQL files
│   ├── data/                   # Database data
│   └── init/                   # Init scripts
│       └── 01-init.sql
│
└── redis/                      # Redis files
    ├── data/                   # Persistence data
    └── redis.conf              # Redis configuration
```

## Quick Start

### 1. Clone หรือสร้างโครงสร้าง

```bash
git clone <repository-url>
cd n8n-docker

# หรือสร้างโครงสร้างด้วย
make setup
```

### 2. ตั้งค่า Environment Variables

```bash
cp .env.example .env
# แก้ไข .env ตามความต้องการ

# สร้าง encryption key
openssl rand -base64 32
```

### 3. เริ่มใช้งาน

```bash
# Option 1: ใช้ script
chmod +x start.sh
./start.sh all

# Option 2: ใช้ Make
make up

# Option 3: ใช้ Docker Compose โดยตรง
docker-compose -f docker-compose.yml \
               -f compose/postgres.yml \
               -f compose/redis.yml \
               -f compose/n8n.yml \
               up -d
```

## การใช้งานแบบต่างๆ

### 1. Full Stack (PostgreSQL + Redis + n8n)
เหมาะสำหรับ production หรือการใช้งานหนัก

```bash
# Using script
./start.sh all

# Using Make
make up

# Using Docker Compose
docker-compose -f docker-compose.yml \
               -f compose/postgres.yml \
               -f compose/redis.yml \
               -f compose/n8n.yml \
               up -d
```

### 2. Standalone (n8n + SQLite)
เหมาะสำหรับทดสอบหรือใช้งานเบาๆ

```bash
# Using script
./start.sh standalone

# Using Make
make up-standalone

# Using Docker Compose
docker-compose -f docker-compose.yml \
               -f compose/n8n-standalone.yml \
               up -d
```

### 3. n8n + PostgreSQL Only
เหมาะสำหรับการใช้งานปานกลาง ไม่ต้องการ queue mode

```bash
# Using script
./start.sh postgres

# Using Make
make up-postgres

# Using Docker Compose
docker-compose -f docker-compose.yml \
               -f compose/postgres.yml \
               -f compose/n8n-postgres-only.yml \
               up -d
```

## Management Commands

### ด้วย Script (start.sh)

```bash
./start.sh all          # เริ่มทุก services
./start.sh standalone   # เริ่ม n8n standalone
./start.sh postgres     # เริ่ม n8n + PostgreSQL
./start.sh down         # หยุดทุก services
./start.sh restart      # restart services
./start.sh logs         # ดู logs
./start.sh logs -f      # ดู logs แบบ follow
./start.sh ps           # ดูสถานะ containers
./start.sh backup       # สร้าง backup
./start.sh help         # ดู help
```

### ด้วย Makefile

```bash
make up               # เริ่มทุก services
make up-standalone    # เริ่ม n8n standalone
make up-postgres      # เริ่ม n8n + PostgreSQL
make down             # หยุด services
make restart          # restart services
make logs             # ดู logs
make logs-n8n         # ดู logs เฉพาะ n8n
make ps               # ดูสถานะ
make backup           # backup ทั้งหมด
make db-backup        # backup เฉพาะ database
make clean            # ลบ containers และ volumes
make setup            # สร้างโครงสร้างเริ่มต้น
```

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `N8N_HOST` | n8n host binding | `0.0.0.0` | No |
| `N8N_PORT` | n8n port | `5678` | No |
| `N8N_PROTOCOL` | Protocol (http/https) | `https` | Yes |
| `WEBHOOK_URL` | Public webhook URL | - | Yes |
| `POSTGRES_DB` | PostgreSQL database name | `n8n` | Yes* |
| `POSTGRES_USER` | PostgreSQL username | `n8n_user` | Yes* |
| `POSTGRES_PASSWORD` | PostgreSQL password | - | Yes* |
| `N8N_BASIC_AUTH_USER` | n8n admin username | `admin` | Yes |
| `N8N_BASIC_AUTH_PASSWORD` | n8n admin password | - | Yes |
| `N8N_ENCRYPTION_KEY` | Encryption key for credentials | - | Yes |
| `GENERIC_TIMEZONE` | Timezone | `Asia/Bangkok` | No |

\* Required only when using PostgreSQL

## Backup & Restore

### Backup ทั้งหมด
```bash
# Using script
./start.sh backup

# Using Make
make backup

# Manual
tar -czf backup-$(date +%Y%m%d).tar.gz n8n/ postgres/ redis/
```

### Backup PostgreSQL
```bash
# Using Make
make db-backup

# Manual
docker-compose exec postgres pg_dump -U n8n_user n8n > backup.sql
```

### Restore PostgreSQL
```bash
# Manual restore
docker-compose exec -T postgres psql -U n8n_user n8n < backup.sql
```

## Reverse Proxy Setup

### Nginx Configuration
```nginx
server {
    listen 443 ssl http2;
    server_name n8n.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
    }
}
```

## Monitoring & Debugging

### ดู Logs
```bash
# All services
./start.sh logs -f

# Specific service
docker-compose logs -f n8n-app
docker-compose logs -f n8n-postgres
docker-compose logs -f n8n-redis
```

### เข้า Shell
```bash
# n8n
docker-compose exec n8n-app /bin/sh

# PostgreSQL
docker-compose exec n8n-postgres /bin/bash

# Redis
docker-compose exec n8n-redis /bin/sh
```

### Health Check
```bash
# Using Make
make health

# Manual
docker-compose exec postgres pg_isready
docker-compose exec redis redis-cli ping
curl http://localhost:5678/healthz
```

## Troubleshooting

### 1. n8n ไม่สามารถเชื่อมต่อ PostgreSQL
```bash
# ตรวจสอบ PostgreSQL status
docker-compose ps postgres
docker-compose logs postgres

# ตรวจสอบ connection
docker-compose exec postgres pg_isready

# ตรวจสอบ environment variables
cat .env | grep POSTGRES
```

### 2. Redis connection errors
```bash
# ตรวจสอบ Redis status
docker-compose ps redis
docker-compose exec redis redis-cli ping

# ดู Redis logs
docker-compose logs redis
```

### 3. Permission issues
```bash
# Fix permissions
sudo chown -R $USER:$USER n8n/ postgres/ redis/
```

### 4. Port already in use
```bash
# เปลี่ยน port ใน .env
N8N_PORT=5679

# หรือหา process ที่ใช้ port
sudo lsof -i :5678
```

## Security Best Practices

1. **รหัสผ่าน**
   - ใช้รหัสผ่านที่ซับซ้อน (ตัวพิมพ์ใหญ่-เล็ก, ตัวเลข, อักขระพิเศษ)
   - เปลี่ยนรหัสผ่าน default ทั้งหมด
   - ใช้ password manager

2. **Encryption**
   - สร้าง encryption key ด้วย `openssl rand -base64 32`
   - เก็บ key ให้ปลอดภัย
   - ไม่ share key

3. **Network**
   - ใช้ firewall จำกัดการเข้าถึง
   - ใช้ SSL/TLS สำหรับ production
   - ไม่ expose ports ที่ไม่จำเป็น

4. **Updates**
   - อัพเดท Docker images เป็นประจำ
   - ติดตาม security advisories
   - ทำ backup ก่อน update

5. **Files**
   - ไม่ commit .env ขึ้น git
   - ใช้ .gitignore
   - Backup เป็นประจำ

## Performance Optimization

### PostgreSQL Tuning
แก้ไขใน `postgres/init/01-init.sql`:
```sql
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
```

### Redis Tuning
แก้ไขใน `redis/redis.conf`:
```
maxmemory 256mb
maxmemory-policy allkeys-lru
```

### n8n Settings
ใน `.env`:
```
N8N_LOG_LEVEL=warn  # ลด log verbosity
N8N_DIAGNOSTICS_ENABLED=false
```

## Development

### Local Development
```bash
# Start in development mode
docker-compose -f docker-compose.yml \
               -f compose/postgres.yml \
               -f compose/redis.yml \
               -f compose/n8n.yml \
               -f docker-compose.override.yml \
               up
```

### Custom Nodes
วาง custom nodes ใน `n8n/config/nodes/`

## License

[Specify your license]

## Contributing

[Contributing guidelines]

option 
ngrok http 5678

## Support

- Documentation: https://docs.n8n.io
- Community: https://community.n8n.io
- GitHub: https://github.com/n8n-io/n8n