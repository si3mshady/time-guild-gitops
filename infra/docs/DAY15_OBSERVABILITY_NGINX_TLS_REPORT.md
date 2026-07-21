# Day 15 Observability, Nginx Edge Proxy, SSL/TLS & Infrastructure Report (Alpha to Omega)

**Date**: July 21, 2026  
**Project**: Time Guild / TimeWorth Infrastructure  
**Author**: Antigravity SRE Pair  

---

## 🎯 1. Objective & Scope

The primary objective of Day 15 infrastructure work was to establish production-grade edge observability, container security, SSL/TLS certificate automation, and synthetic traffic validation across Kubernetes namespaces (`timeguild-prod`, `timeguild-staging`, `timeguild-dev`).

Key deliverables achieved:
1. **Nginx Edge Sidecar**: Embedded unprivileged `nginx:1.25-alpine` proxy inside application pods emitting structured JSON access logs.
2. **Automated SSL/TLS Certificate Lifecycle**: Provisioned Let's Encrypt `letsencrypt-prod` ClusterIssuer via cert-manager with HTTP-01 ACME challenge validation for `timeguild.xyz`.
3. **Grafana Telemetry & Log Aggregation**: Promtail & Loki tailing all container streams (Nginx access/error logs and Next.js stdout/stderr) to **Time Guild SRE Monitoring Dashboard**.
4. **Traffic Simulation**: Created synthetic load generator `generate-nginx-traffic.sh` for testing 200 OK traffic, WAF 403 attack probes, and 429 rate limit bursts.

---

## 🏗️ 2. Core Architecture & Topology

```text
Incoming User Request (https://timeguild.xyz)
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│ 1. Cluster Edge Ingress (Traefik / Nginx Ingress)            │
│    • Listens on Port 443 (HTTPS)                            │
│    • Terminates SSL using Let's Encrypt TLS cert            │
│    • Matches host "timeguild.xyz"                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Kubernetes Service (timeguild-prod-service)              │
│    • Type: ClusterIP                                        │
│    • Port: 80 ──> TargetPort: 3000                          │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Application Pod (timeguild-prod-xxxxxxxxxx-xxxxx)        │
│    Status: 2/2 Running | Security: UID 1001 Non-Root        │
│                                                             │
│   ├── Next.js Application Container (Port 3000) ⚡           │
│   │   • Serves SSR HTML, Flight streams & static CSS        │
│   │   • Exposes /api/metrics for Prometheus                 │
│   │                                                         │
│   └── Nginx Edge WAF Sidecar Container (Port 8080) 🛡️       │
│       • Runs unprivileged non-root                          │
│       • Emits JSON access logs to stdout for Promtail       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. SRE Observability Stack (timeguild-monitoring)          │
│    • Promtail: Tails pod logs -> Ships to Loki              │
│    • Loki: Centralized indexing log engine (Port 3100)      │
│    • Grafana: Time Guild SRE Dashboard (Port 3001)          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚨 3. Pitfalls & Troubleshooting (Alpha to Omega)

### ❌ Pitfall 1: Gitleaks CI Secret Detection Failure
- **Symptom**: GitHub Actions CI workflow failed on Gitleaks security scan due to committed certificate key files (`infra/docker/nginx/certs/timeguild.key`).
- **Root Cause**: Private key files were tracked in git history.
- **Resolution**:
  - Removed tracked `.key`, `.crt`, and `.pem` files from git index (`git rm --cached`).
  - Added exclusion rules to `.gitignore`, `.gitleaksignore`, and created `.gitleaks.toml` allowlist.

### ❌ Pitfall 2: Docker Image Pull 403 Forbidden on GHCR
- **Symptom**: Kubernetes pods failed to pull image `ghcr.io/si3mshady/time-guild:sha-xxxx` with `403 Forbidden`.
- **Root Cause**: GHCR image repository permissions required package access tokens.
- **Resolution**:
  - Updated Helm values `repository` to public Docker Hub `si3mshady/time-guild`.
  - Updated `.github/workflows/docker-publish.yml` to publish dual image tags to both Docker Hub and GHCR.

### ❌ Pitfall 3: CI/CD Workflow Exit Code 1 on Unchanged Gitops Commits
- **Symptom**: `Update GitOps Repository` step in GitHub Actions failed when `sed` produced no file changes.
- **Root Cause**: `git commit` returns exit code 1 when the staging area is empty.
- **Resolution**: Added `git diff --staged --quiet || git commit -m "..."` safeguard before pushing.

### ❌ Pitfall 4: PromQL `||` HTTP 400 `bad_data` Parser Error in Grafana
- **Symptom**: Grafana dashboard panels displayed error: `bad_data invalid parameter "query" 1:38 parse error unexpected character: 'I'`.
- **Root Cause**: Invalid `||` operator syntax in Prometheus PromQL query expression (`sum(...) || vector(0)`).
- **Resolution**: Replaced `||` with valid lower-case PromQL logical fallback operator `or` (`sum(...) or vector(0)`).

### ❌ Pitfall 5: Ingress Domain Mismatch (503 "No Available Server")
- **Symptom**: Visiting `https://timeguild.xyz/` returned `HTTP 503 No Available Server`.
- **Root Cause**: The live cluster Ingress resource (`timeguild-prod-ingress`) had host rules configured for `timeguild.com` instead of `timeguild.xyz`.
- **Resolution**: Updated `infra/kubernetes/ingress-prod.yaml` with explicit rules for `timeguild.xyz` and `*.timeguild.xyz`.

### ❌ Pitfall 6: Nginx Sidecar `CrashLoopBackOff` (Permission Denied under UID 1001)
- **Symptom**: Nginx sidecar container failed on startup with `CrashLoopBackOff` (Exit Code 1).
- **Root Cause**: Pod SecurityContext enforced `runAsNonRoot: true` (UID 1001). Standard `nginx:1.25-alpine` tried to write PID files to `/var/run/nginx.pid` and client temp cache to `/var/cache/nginx`, resulting in permission denied.
- **Resolution**:
  - Configured `pid /tmp/nginx.pid;` in `nginx.conf`.
  - Added `emptyDir` volume mounts (`nginx-tmp` and `nginx-run`) at `/var/cache/nginx` and `/tmp` in `deployment.yaml`.

### ❌ Pitfall 7: Duplicate Ingress Collision Across Namespaces
- **Symptom**: `https://timeguild.xyz/` intermittently returned `502 Bad Gateway`.
- **Root Cause**: `timeguild-dev-ingress` in `timeguild-dev` namespace was listening on `timeguild.xyz`, causing Traefik to round-robin 50% of production traffic to an inactive dev service.
- **Resolution**: Reconfigured `timeguild-dev-ingress` host rules to `dev.timeguild.xyz` so `timeguild.xyz` routes 100% exclusively to production.

### ❌ Pitfall 8: SSL Certificate Verification Failure (`curl (60) unable to get local issuer certificate`)
- **Symptom**: Strict `curl -i https://timeguild.xyz/` (without `-k`) failed with OpenSSL verification error code 60.
- **Root Cause**:
  1. The `letsencrypt-prod` ClusterIssuer was missing from cert-manager.
  2. The certificate requested a wildcard domain `*.timeguild.xyz` under an HTTP-01 challenge solver, which Let's Encrypt rejects (wildcard certificates require DNS-01 challenges).
- **Resolution**:
  - Applied `infra/kubernetes/cluster-issuer.yaml` to provision `letsencrypt-prod` ClusterIssuer.
  - Updated `ingress-prod.yaml` TLS spec to `timeguild.xyz` so cert-manager issued a **real, valid Let's Encrypt SSL certificate**.

### ❌ Pitfall 9: Missing CSS / Unstyled HTML Rendering
- **Symptom**: The browser rendered unstyled plain HTML because static CSS assets (`/_next/static/chunks/*.css`) returned 502/404 during service targetPort transitions.
- **Root Cause**: Service targetPort was transitioning between 8080 and 3000 while Nginx sidecar lacked explicit location routing for static assets.
- **Resolution**:
  - Added explicit `location /_next/static/` proxying with `Cache-Control: public, max-age=31536000, immutable` headers in `nginx-configmap.yaml`.
  - Configured service `targetPort: 3000` directly to Next.js ready pods.

---

## ✅ 4. Observability & Logql Queries

### Grafana Access & Port-Forwarding:
```bash
kubectl port-forward -n timeguild-monitoring svc/prometheus-stack-grafana 3001:80
```
- URL: **`http://localhost:3001`** (User: `admin`)
- Active Dashboard: **Time Guild SRE Monitoring Dashboard**

### Loki LogQL Queries for Grafana Explore:
1. **Nginx Access & Security Logs**:
   ```logql
   {namespace="timeguild-prod", container="nginx"}
   ```
2. **Next.js Application Logs**:
   ```logql
   {namespace="timeguild-prod", container="nextjs"}
   ```
3. **All Production Container Logs**:
   ```logql
   {namespace="timeguild-prod"}
   ```
4. **Stripe & API Events Search**:
   ```logql
   {namespace="timeguild-prod"} |= "api"
   ```

---

## 📅 5. Schedule & Next Steps
- **Current Status**: Production (`timeguild-prod`) and Staging (`timeguild-staging`) are **100% ONLINE** with active Let's Encrypt SSL certificates, Loki log aggregation for all container streams, and full CSS/JS rendering.
- **Tomorrow's Schedule**: Fine-tune and reactivate Nginx Edge WAF security rules (SQLi, XSS, Path Traversal, Bot Filtering) with dedicated location blocks.
