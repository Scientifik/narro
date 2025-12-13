# Nginx Configuration for Narro

This guide covers Nginx setup and SSL/TLS configuration for Narro deployment.

> **Note:** Nginx configuration files are located in `deployment/nginx/`. This guide explains how to use them.

## Files

- `deployment/nginx/nginx.conf` - Single-server configuration (API and Web on same machine)
- `deployment/nginx/nginx.lb.conf` - Load balancer configuration (multi-server setup)

## SSL/TLS Setup with Let's Encrypt

### Initial Setup

1. **Install Certbot:**
   ```bash
   sudo apt-get update
   sudo apt-get install certbot python3-certbot-nginx
   ```

2. **Obtain SSL Certificate:**
   ```bash
   sudo certbot --nginx -d narro.info -d www.narro.info
   ```

3. **Certbot will:**
   - Automatically configure Nginx with SSL
   - Set up auto-renewal
   - Update the nginx.conf with certificate paths

### Auto-Renewal

Certbot sets up automatic renewal via systemd timer. Verify it's active:

```bash
sudo systemctl status certbot.timer
```

Test renewal manually:

```bash
sudo certbot renew --dry-run
```

## Configuration

### Single-Server Setup

1. Copy `deployment/nginx/nginx.conf` to `/etc/nginx/sites-available/narro`
2. Create symlink: `sudo ln -s /etc/nginx/sites-available/narro /etc/nginx/sites-enabled/`
3. Test configuration: `sudo nginx -t`
4. Reload Nginx: `sudo systemctl reload nginx`

### Multi-Server Setup

1. Update `deployment/nginx/nginx.lb.conf` with actual server IPs
2. Copy to `/etc/nginx/sites-available/narro`
3. Follow same steps as single-server setup

## Important Notes

- Ensure Docker network `narro-network` is accessible to Nginx
- If Nginx runs in Docker, use `network_mode: "host"` or connect to Docker network
- Update server_name if using different domain
- SSL certificates are stored in `/etc/letsencrypt/live/narro.info/`

## Troubleshooting

- Check Nginx logs: `sudo tail -f /var/log/nginx/narro-error.log`
- Test configuration: `sudo nginx -t`
- Check SSL certificate: `sudo certbot certificates`
- Verify ports are open: `sudo netstat -tlnp | grep nginx`

## Related Documentation

- [Deployment Guide](deployment-guide.md) - Complete deployment setup
- [Deployment Summary](deployment-summary.md) - Overview of deployment infrastructure









