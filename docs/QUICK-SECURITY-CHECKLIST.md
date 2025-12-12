# Quick Security Checklist

## Before Each Push to Main

```bash
cd web

# 1. Check for vulnerabilities (should show "found 0 vulnerabilities")
npm audit
→ If fails, run: npm audit fix

# 2. Check for outdated packages (informational)
npm outdated
→ Update patch versions: npm update
→ Update minor/major: npm install package@latest

# 3. Build test (same as CI/CD)
npm run build
→ Should complete without errors

# 4. Commit and push
git add .
git commit -m "Update dependencies"
git push origin main
```

## What CI/CD Does Now

✅ Runs npm audit automatically on every push
✅ Fails build if moderate/high vulnerabilities found
✅ Reports outdated packages
✅ Blocks deployment until security is fixed

## Red Flags 🚩

- `npm audit` shows **moderate or higher** vulnerabilities
- Build fails in CI/CD with audit error
- Outdated packages with known CVEs (check advisories)

## Safe Updates

```bash
# Patch updates (safe - do weekly)
npm update

# Specific package
npm install react@latest

# Test after updating
npm run build
```

## If Stuck

1. Read the audit error message
2. Identify the vulnerable package
3. Try: `npm audit fix`
4. If that doesn't work: `npm install package@latest`
5. Test build: `npm run build`
6. If still broken, check GitHub issues for that package

## Resources

- Security guide: `docs/SECURITY-DEPENDENCIES.md`
- npm audit help: `npm audit --help`
- Package info: `npm view package-name`
- GitHub advisories: https://github.com/advisories

---

**TL;DR:** Run `npm audit` before pushing. If it fails, run `npm audit fix`.
