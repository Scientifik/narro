# Deployment Scripts

## Files

- `scripts/provision-ubuntu.sh` - One-time server provisioning script for Ubuntu 22.04 LTS
- `scripts/deploy.sh` - Deployment script that pulls images from registry and starts containers
- `scripts/env.prod` - Example production environment file template

## Quick Start

### 1. Provision Server (One-time, as root)

```bash
# On your Ubuntu 22.04 server, as root:
DOMAIN=alpha.narro.info bash /path/to/scripts/provision-ubuntu.sh
```

This will:
- Install Docker and Docker Compose
- Install and configure Nginx
- Create narro user and directory structure
- Set up basic Nginx configuration

### 2. Configure Environment (as narro user)

```bash
# Switch to narro user
su - narro
cd ~/deployment

# Copy docker-compose.yml to this directory
cp /path/to/docker-compose.yml .

# Create .env.production from template
cp ../scripts/env.prod .env.production

# Edit with your secrets
nano .env.production

# Set secure permissions
chmod 600 .env.production
```

### 3. Get SSL Certificate (as root)

```bash
certbot --nginx -d alpha.narro.info
```

This will automatically:
- Obtain SSL certificates
- Create HTTPS server block
- Configure redirects from HTTP to HTTPS

### 4. Deploy (as narro user)

```bash
cd ~/deployment
./scripts/deploy.sh
```

This will:
- Pull images from registry
- Start containers
- Perform health checks

## Directory Structure

After provisioning, your server will have:

```
/home/narro/
└── deployment/
    ├── docker-compose.yml    # Copy this from repo
    ├── .env.production       # Your secrets (create this)
    └── scripts/
        ├── deploy.sh
        └── env.prod          # Template
```

## Environment Variables

See `env.prod` for all required environment variables. Key ones:

- `REGISTRY_URL` - Container registry (e.g., `ord.vultrcr.com/narro`)
- `REGISTRY_USER` - Registry username
- `REGISTRY_PASSWORD` - Registry password
- `IMAGE_TAG` - Image tag to deploy (default: `latest`)
- `DATABASE_URL` - Supabase PostgreSQL connection string
- `SUPABASE_*` - Supabase configuration
- `NEXT_PUBLIC_*` - Frontend environment variables

## Troubleshooting

### Docker not accessible
```bash
# Ensure Docker is running
sudo systemctl start docker

# Check user is in docker group
groups

# If not, add and relogin:
sudo usermod -aG docker narro
# Then log out and back in
```

### Ports already in use
```bash
# Check what's using ports 3000/3001
sudo netstat -tlnp | grep -E '3000|3001'
```

### Container won't start
```bash
# Check logs
docker compose logs narro-api
docker compose logs narro-web

# Check container status
docker compose ps
```

## Notes

- All scripts assume running in `/home/narro/deployment`
- Docker Compose uses the newer `docker compose` syntax (not `docker-compose`)
- Secrets are stored in `.env.production` (NOT in git)
- SSL certificates are managed by Certbot
- Services run on ports 3000 (API) and 3001 (Web) internally
- Nginx proxies these to port 80/443
