# Security & Dependency Management

## Overview

This guide documents how Narro handles dependency security and prevents supply-chain attacks through automated security checks in CI/CD.

## Automated Security Checks

### Gitea Actions Workflow

The `.gitea/workflows/build-and-deploy.yml` workflow includes a **security-audit** job that runs before building and deploying:

```yaml
security-audit:
  - Sets up Node.js 20
  - Installs dependencies using npm ci (clean install)
  - Runs npm audit --audit-level=moderate (FAILS on moderate or higher vulnerabilities)
  - Reports outdated packages (for monitoring)
```

### How It Works

1. **Every push to `main` branch** triggers the workflow
2. **Security audit runs first** before any Docker builds or deployments
3. **Build/deploy is blocked** if vulnerabilities are found
4. **Outdated packages are reported** (informational only)

### Vulnerability Levels

The workflow fails on **moderate or higher** severity vulnerabilities:

| Level | Action |
|-------|--------|
| Critical | ❌ Build FAILS |
| High | ❌ Build FAILS |
| Moderate | ❌ Build FAILS |
| Low | ✅ Build continues (for monitoring) |

## Local Development

### Before Committing

Always run these commands locally:

```bash
cd web

# Check for vulnerabilities
npm audit

# Check for outdated packages
npm outdated

# Fix auto-fixable vulnerabilities (use with caution)
npm audit fix

# Clean install (same as CI/CD uses)
npm ci
```

### If Build Fails in CI/CD

If the security audit job fails:

1. **Read the audit output** - It will list the vulnerable packages
2. **Local reproduction:**
   ```bash
   cd web
   npm ci
   npm audit
   ```
3. **Fix options:**
   - **Auto-fix (if available):** `npm audit fix`
   - **Manual update:** `npm update package-name`
   - **Major version:** `npm install package@latest`

### Workflow

```
Push to main
    ↓
Security Audit Job Runs
    ├─ Install dependencies
    ├─ Run npm audit (--audit-level=moderate)
    └─ Report outdated packages
    ↓
IF vulnerabilities found → ❌ STOP (workflow fails)
IF clean → ✅ Continue to build/deploy
```

## Regular Maintenance

### Weekly

```bash
cd web
npm audit  # Check for new vulnerabilities
```

### Monthly

```bash
cd web
npm outdated              # Check for updates
npm update               # Apply patch/minor updates
npm run build            # Test the build
```

### Before Major Releases

1. Review `npm outdated` output
2. Plan Next.js and major dependency updates
3. Test each major version upgrade in isolation
4. Update in batches (don't update everything at once)

## Dependency Update Strategy

### Patch Updates (Safe)
- `react@19.2.1` → `19.2.3` - Apply immediately
- Automatic security patches
- No breaking changes expected

```bash
npm update
```

### Minor Updates (Review)
- `tailwindcss@4.1.17` → `4.1.18`
- Usually safe but test your build
- Check release notes for breaking changes

```bash
npm install package@^4.2.0
npm run build  # Test before committing
```

### Major Updates (Plan)
- `next@15.5.9` → `16.0.10` - Plan & test separately
- `@sentry/nextjs@8.55.0` → `10.30.0` - Major feature changes
- May require code changes

```bash
npm install next@16 eslint-config-next@16
npm run build
# Test thoroughly before deploying
```

## Security Best Practices

### 1. Always Use `npm ci` in CI/CD
- **Good:** `npm ci` (uses exact versions from package-lock.json)
- **Bad:** `npm install` (may use newer patch versions)

### 2. Review Dependencies
- Keep dependencies list small
- Remove unused packages: `npm prune`
- Check package maintenance status

### 3. Lock File Management
- ✅ Commit `package-lock.json` to git
- ✅ Review lock file changes in PRs
- ✅ Keep lock file in sync with package.json

### 4. Vulnerability Response Time
- **Critical/High:** Fix within 24 hours
- **Moderate:** Fix within 1 week
- **Low:** Monitor and plan update

### 5. Supply-Chain Security
- Use package author verification: `npm view package-name`
- Check weekly download trends (unusual spikes = red flag)
- Monitor GitHub security advisories: https://github.com/advisories
- Consider using `npm install --audit-level=high` locally

## Current Dependencies Status

### Web App (`web/package.json`)
- **Total packages:** 12 (including devDependencies)
- **Vulnerability audit:** ✅ 0 found
- **Last audit:** December 11, 2024

**Key Dependencies:**
- `next@15.5.9` - Next.js framework
- `react@19.2.1`, `react-dom@19.2.1` - React library
- `tailwindcss@4.1.17` - CSS framework
- `@sentry/nextjs@8.55.0` - Error tracking
- `typescript@5.9.3` - Type checking

**Packages with updates available:**
- See `npm outdated` for full list
- Patch updates are safe to apply
- Major updates should be tested separately

## Troubleshooting

### "npm audit" shows vulnerabilities

**Common causes:**
1. Transitive dependencies (dependencies of dependencies)
2. Newly discovered vulnerability in a package you're using

**Resolution:**
```bash
npm audit fix        # Try automatic fix
npm audit fix --force # Force major version updates (risky)
npm install package@latest  # Manual update to latest
```

### Build fails in CI/CD but works locally

**Likely cause:** Local `node_modules` is out of sync

**Fix:**
```bash
rm -rf node_modules package-lock.json
npm ci  # Clean install using lock file
npm audit
npm run build
```

### Outdated packages warning

If `npm outdated` shows many outdated packages:

1. **Don't panic** - "outdated" ≠ "vulnerable"
2. **Review priorities:**
   - Critical: Zero-day vulnerabilities
   - High: Known exploits
   - Optional: Features or maintenance updates
3. **Plan updates in batches** (not all at once)

## Monitoring

### Check Workflow Status
- Go to Gitea repository → Actions
- View security-audit job results
- See package audit report and outdated packages

### GitHub Security Advisories
- Monitor: https://github.com/advisories
- Search by package name
- Subscribe to your top packages

### npm Security
- View your package security profile: `npm audit --omit=dev --json`
- Set registry security level: `npm config set audit-level=moderate`

## Related Files

- `.gitea/workflows/build-and-deploy.yml` - CI/CD with security checks
- `web/package.json` - Web app dependencies
- `web/package-lock.json` - Locked dependency versions
- `web/Dockerfile` - Container build (uses `npm ci`)

---

**Last Updated:** December 11, 2024
