# RSS Feeds Reverse Proxy Setup

This sets up a lightweight nginx reverse proxy at `feeds.narro.info` that forwards requests to the Supabase Edge Function with automatic authentication.

## Architecture

```
RSS Reader
    ↓
feeds.narro.info/{feedId}.rss (Port 80/443)
    ↓
nginx (reverse proxy)
    ↓
Add Authorization header
    ↓
kldhpsgmbtfzmollexod.supabase.co/functions/v1/rss-feed/{feedId}.rss
    ↓
Edge Function + PostgreSQL
```

## Prerequisites

- Docker and Docker Compose installed
- Domain `feeds.narro.info` configured
- DNS A record pointing to your server IP
- Ports 80 and 443 open on your firewall

## Setup Instructions

### Step 1: Configure DNS

Update your domain registrar to point `feeds.narro.info` to your server:

```
A record: feeds.narro.info → <your-server-ip>
```

Wait for DNS propagation (5-10 minutes).

### Step 2: Create Required Directories

```bash
cd /path/to/narro
mkdir -p deployment/nginx/ssl
mkdir -p deployment/nginx/certbot
mkdir -p logs/nginx
```

### Step 3: Initialize SSL Certificates

On your server, run the initial certificate request:

```bash
sudo certbot certonly \
  --standalone \
  -d feeds.narro.info \
  --email admin@narro.info \
  --agree-tos \
  --non-interactive
```

This creates certificates at:
- `/etc/letsencrypt/live/feeds.narro.info/cert.pem`
- `/etc/letsencrypt/live/feeds.narro.info/key.pem`

Copy them to your deployment directory:

```bash
sudo cp -r /etc/letsencrypt/live/feeds.narro.info deployment/nginx/ssl/
sudo chown -R $(whoami) deployment/nginx/ssl/
```

### Step 4: Deploy with Docker Compose

```bash
cd deployment

# Start the services
docker-compose -f docker-compose.feeds.yml up -d

# Check status
docker-compose -f docker-compose.feeds.yml ps

# View logs
docker-compose -f docker-compose.feeds.yml logs -f nginx-feeds
```

### Step 5: Verify Setup

Test the proxy with a valid feed ID:

```bash
curl -v https://feeds.narro.info/{feedId}.rss
```

You should see:
- Status: 200 OK
- Content-Type: application/rss+xml
- Valid RSS 2.0 XML content
- Header: X-Cache-Status (HIT/MISS)

## Configuration Details

### nginx Configuration (`deployment/nginx/feeds.conf`)

- **Upstream:** Connects to Supabase Edge Function
- **Authorization Header:** Automatically adds Bearer token with anon key
- **SSL/TLS:** Configured for modern security (TLSv1.2+)
- **Caching:** 15 minutes (matches Edge Function cache)
- **Compression:** Gzip enabled for RSS (smaller responses)
- **Security Headers:** X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **Health Check:** `/health` endpoint returns 200 OK

### Path Mapping

```
Input:  feeds.narro.info/{feedId}.rss
Output: kldhpsgmbtfzmollexod.supabase.co/functions/v1/rss-feed/{feedId}.rss
Header: Authorization: Bearer sb_publishable_0n0Zfl0ePcvyBHsx99hhPQ_XRH-lJ8v
```

## Maintenance

### SSL Certificate Renewal

Certificates are automatically renewed daily via certbot container. Manual renewal:

```bash
docker-compose -f docker-compose.feeds.yml exec certbot certbot renew
```

### View Logs

```bash
# Nginx access logs
docker-compose -f docker-compose.feeds.yml logs nginx-feeds

# Certbot logs
docker-compose -f docker-compose.feeds.yml logs certbot
```

### Restart Services

```bash
docker-compose -f docker-compose.feeds.yml restart nginx-feeds
```

### Stop Services

```bash
docker-compose -f docker-compose.feeds.yml down
```

## Troubleshooting

### Certificate Errors

If certificates fail:

```bash
# Remove old certificates
sudo rm -rf /etc/letsencrypt/live/feeds.narro.info

# Request new certificate
sudo certbot certonly --standalone -d feeds.narro.info --email admin@narro.info --agree-tos --non-interactive

# Copy to deployment
sudo cp -r /etc/letsencrypt/live/feeds.narro.info deployment/nginx/ssl/
```

### 502 Bad Gateway

Check if Supabase is reachable:

```bash
docker-compose -f docker-compose.feeds.yml exec nginx-feeds curl -I https://kldhpsgmbtfzmollexod.supabase.co
```

### DNS Issues

Verify DNS resolution:

```bash
nslookup feeds.narro.info
dig feeds.narro.info
```

### Cache Issues

Clear nginx cache:

```bash
docker-compose -f docker-compose.feeds.yml exec nginx-feeds rm -rf /var/cache/nginx/*
```

## Performance

- **Request Path:** ~50-100ms (local proxy) + Edge Function latency
- **Cache Hit:** ~10-20ms (15-minute cache)
- **Cache Miss:** ~500ms-1s (database queries + Edge Function)
- **Bandwidth:** ~50KB per request (average RSS feed)

## Security

- ✅ HTTPS/TLS encryption (Let's Encrypt)
- ✅ Bearer token authentication (Supabase anon key)
- ✅ Security headers (XSS, clickjacking protection)
- ✅ No direct access to Supabase API
- ✅ Rate limiting via Supabase (optional)
- ⚠️ Anon key is visible in nginx config (acceptable for public RSS feeds)

## Costs

- **Server:** Your existing Vultr VPS
- **Bandwidth:** Counted against your VPS bandwidth
- **SSL:** Free (Let's Encrypt)
- **Supabase:** Edge Function execution cost only (minimal)

Total incremental cost: **$0** (uses existing infrastructure)

## Testing with RSS Readers

Popular RSS readers to test:

1. **Feedly** - https://feedly.com
2. **Inoreader** - https://www.inoreader.com
3. **NetNewsWire** - https://netnewswire.com (macOS/iOS)
4. **Thunderbird** - RSS feed reader
5. **QuiteRSS** - Desktop app

Add feed URL: `https://feeds.narro.info/{feedId}.rss`

## Next Steps

1. ✅ Deploy this proxy
2. ✅ Test with real feed IDs
3. Update web/mobile apps to use `https://feeds.narro.info/{feedId}.rss`
4. Monitor logs for errors
5. Optionally add rate limiting/authentication to Supabase function

## Support

If you encounter issues:

1. Check nginx logs: `docker-compose logs nginx-feeds`
2. Verify DNS: `dig feeds.narro.info`
3. Test Edge Function directly: `curl -H "Authorization: Bearer sb_publishable_0n0Zfl0ePcvyBHsx99hhPQ_XRH-lJ8v" https://kldhpsgmbtfzmollexod.supabase.co/functions/v1/rss-feed/{feedId}.rss`
4. Verify SSL cert: `openssl s_client -connect feeds.narro.info:443`
