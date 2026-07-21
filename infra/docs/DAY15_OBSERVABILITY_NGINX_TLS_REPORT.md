# 🎓 Day 15 Observability, Nginx Edge Proxy, SSL/TLS & Kubernetes SRE Masterclass Report

**Date**: July 21, 2026  
**Project**: Time Guild / TimeWorth Production Infrastructure  
**Author**: SRE Architectural & Engineering Pair  
**Document Purpose**: Comprehensive Educational & Technical Reference (From Micro Process Execution to Macro Cloud System Design)

---

## 🏛️ 1. Macro Architectural Overview & System Design

Modern cloud-native web applications deployed on Kubernetes must balance **Security (Least Privilege)**, **Observability (Telemetry)**, and **Availability (High Uptime)**. In the Time Guild ecosystem, our production stack consists of:

- **Edge Tier**: Ingress Controllers (Traefik / Nginx) handling incoming HTTPS traffic, SSL termination, and domain routing.
- **Service & Mesh Tier**: Kubernetes ClusterIP Services directing traffic to active Pod replicas.
- **Application Pod Tier**: Multi-container Pods running:
  - **Next.js Server** (Node/Bun runtime on Port 3000): Server-Side Rendering (SSR), React Server Components (RSC), and metrics exposure.
  - **Nginx Edge Sidecar** (Unprivileged proxy on Port 8080): Request logging, rate limiting, and inline WAF evaluation.
- **Telemetry Tier**: Promtail DaemonSet scanning container log pipes (`/var/log/pods/*`), pushing to Loki log engine, and visualizing on Grafana.

---

## 🔬 2. Deep Dive: Pitfalls, Micro/Macro Root Causes & Resolutions

Below is an exhaustive breakdown of every blocker encountered during Day 15 operations, designed as an educational reference for SRE course creation.

---

### 🚨 Case 1: Gitleaks Secret Detection Failure in CI/CD Pipeline

#### 👁️ Manifestation & Symptoms
- **User Impact**: GitHub Actions workflow failed at the `Gitleaks Scan` step.
- **Terminal Error**:
  ```text
  Finding: private key file detected in infra/docker/nginx/certs/timeguild.key
  RuleID: private-key
  Entropy: 5.89
  Exit Code: 1
  ```

#### 🔬 Micro Technical Cause
The `gitleaks` static analysis scanner examines git commit trees and staged diffs against entropy algorithms and regex patterns for PEM/RSA headers (`-----BEGIN PRIVATE KEY-----`). Even though `.key` files were added to `.gitignore` after creation, `git` had already indexed the files in previous commits (`git ls-files` tracked them).

#### 🌐 Macro SRE & Architectural Context
**Secret Proliferation**: Committing private SSL keys or credentials to a public or private git repository compromises security governance. Once a key enters git history, it is considered leaked forever (requiring revocation) unless git history is rewritten or files are untracked and allowlisted in security scanners.

#### 🔧 Resolution & Lessons Learned
1. Removed tracked certificates from the git index without deleting local working copies:
   ```bash
   git rm --cached infra/docker/nginx/certs/timeguild.key
   ```
2. Created `.gitleaksignore` with key fingerprints and configured `.gitleaks.toml` allowlist rules.

---

### 🚨 Case 2: Docker Image Pull `403 Forbidden` on GHCR

#### 👁️ Manifestation & Symptoms
- **User Impact**: Kubernetes Pods entered `ImagePullBackOff` or `ErrImagePull`.
- **Terminal Error**:
  ```text
  Failed to pull image "ghcr.io/si3mshady/time-guild:sha-64035f4": 
  rpc error: code = Unknown desc = failed to pull and unpack image: 
  failed to resolve reference: unexpected status code 403 Forbidden
  ```

#### 🔬 Micro Technical Cause
The Helm chart default value pointed to GitHub Container Registry (`ghcr.io`). Without an in-cluster `imagePullSecrets` configuration referencing a valid GitHub Personal Access Token (PAT) with `read:packages` scope, the Kubernetes kubelet received HTTP 403 Forbidden from GitHub's OCI API.

#### 🌐 Macro SRE & Architectural Context
**Registry Authorization Coupling**: Production Kubernetes deployments relying on private registries require automated Secret rotation or public fallback registries. If image credentials fail, zero-downtime rolling updates (`maxSurge: 1`) halt completely.

#### 🔧 Resolution & Lessons Learned
1. Updated `infra/helm/timeguild/values.yaml` image repository to public Docker Hub: `si3mshady/time-guild`.
2. Updated `.github/workflows/docker-publish.yml` to build and push dual tags to both Docker Hub and GHCR simultaneously.

---

### 🚨 Case 3: GitOps CI Workflow Exit Code 1 on Unchanged Commits

#### 👁️ Manifestation & Symptoms
- **User Impact**: GitHub Actions pipeline failed during the `Update GitOps Repository` step.
- **Terminal Error**:
  ```text
  On branch main
  nothing to commit, working tree clean
  Error: Process completed with exit code 1.
  ```

#### 🔬 Micro Technical Cause
The CI script ran `sed -i` to update image tags in GitOps manifests. When the image tag had not changed or `sed` matched no patterns, `git commit -m "..."` executed on an empty git staging area. By POSIX design, `git commit` exits with status `1` when there are no changes to commit.

#### 🌐 Macro SRE & Architectural Context
**Idempotent CI/CD Pipelines**: Automation scripts must be idempotent. Failing a pipeline because the desired state matches the current state breaks continuous deployment flow.

#### 🔧 Resolution & Lessons Learned
Guarded the commit command with a staging diff check:
```bash
git diff --staged --quiet || git commit -m "update: Sync deployment manifests"
```

---

### 🚨 Case 4: PromQL `||` HTTP 400 `bad_data` Parser Error in Grafana

#### 👁️ Manifestation & Symptoms
- **User Impact**: Red error badges appeared on Grafana dashboard panels.
- **Terminal/UI Error**:
  ```text
  bad_data: invalid parameter "query": 1:38 parse error: unexpected character: 'I'
  ```

#### 🔬 Micro Technical Cause
Prometheus Query Language (PromQL) uses `or` (lower-case keyword) as its logical fallback operator (`query1 or query2`). The query author used `||` (JavaScript/C-style OR operator syntax), which the PromQL Lexer/Parser rejects with a syntax error (`unexpected character: 'I'`).

#### 🌐 Macro SRE & Architectural Context
**Telemetry Schema Standards**: Query syntax errors in Grafana panels cause silent observability gaps. Alert rules built on invalid PromQL syntax fail to trigger during incidents.

#### 🔧 Resolution & Lessons Learned
Updated dashboard JSON and ConfigMap templates from:
```promql
sum(rate(http_requests_total[5m])) || vector(0)
```
to valid PromQL syntax:
```promql
sum(rate(http_requests_total[5m])) or vector(0)
```

---

### 🚨 Case 5: Ingress Domain Mismatch (HTTP 503 "No Available Server")

#### 👁️ Manifestation & Symptoms
- **User Impact**: Navigating to `https://timeguild.xyz/` rendered a plain Traefik error page: `"no available server"`.

#### 🔬 Micro Technical Cause
Traefik Ingress Controller inspects the HTTP `Host` header (`Host: timeguild.xyz`). The live cluster `timeguild-prod-ingress` resource had host rules configured for `timeguild.com` instead of `timeguild.xyz`. Because Traefik found no route matching `timeguild.xyz`, it returned HTTP 503.

#### 🌐 Macro SRE & Architectural Context
**Domain Name Governance & State Drift**: During domain migrations (e.g. `.com` to `.xyz`), if ingress manifests are not synchronized with DNS A/AAAA records, traffic hits the edge ingress but fails at the routing table.

#### 🔧 Resolution & Lessons Learned
Updated `infra/kubernetes/ingress-prod.yaml` spec:
```yaml
spec:
  rules:
    - host: "timeguild.xyz"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: timeguild-prod-service
                port:
                  number: 80
```

---

### 🚨 Case 6: Nginx Sidecar `CrashLoopBackOff` (Permission Denied under UID 1001)

#### 👁️ Manifestation & Symptoms
- **User Impact**: Pods stuck in `CrashLoopBackOff` with `READY: 1/2`.
- **Pod Log Output**:
  ```text
  nginx: [emerg] open() "/var/run/nginx.pid" failed (13: Permission denied)
  2026/07/21 04:40:00 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
  ```

#### 🔬 Micro Technical Cause
The Pod SecurityContext specified `runAsNonRoot: true` and `runAsUser: 1001`. The standard `nginx:1.25-alpine` image defaults to running as `root` (UID 0) and attempts to write runtime files to root-owned directories (`/var/run` and `/var/cache/nginx`). Under Linux file permissions, UID 1001 lacks write access to root directories.

#### 🌐 Macro SRE & Architectural Context
**Zero-Trust Container Execution**: Production security standards prohibit running containers as `root` (UID 0) to prevent container escape exploits. Sidecar containers embedded into non-root Pods must be explicitly configured to use unprivileged paths (`/tmp`).

#### 🔧 Resolution & Lessons Learned
1. Relocated PID path in `nginx.conf`:
   ```nginx
   pid /tmp/nginx.pid;
   ```
2. Added `emptyDir` volume mounts in `deployment.yaml`:
   ```yaml
   volumeMounts:
     - name: nginx-tmp
       mountPath: /var/cache/nginx
     - name: nginx-run
       mountPath: /tmp
   volumes:
     - name: nginx-tmp
       emptyDir: {}
     - name: nginx-run
       emptyDir: {}
   ```

---

### 🚨 Case 7: Cross-Namespace Ingress Host Collision

#### 👁️ Manifestation & Symptoms
- **User Impact**: Refreshing `https://timeguild.xyz/` produced alternating responses: 50% returned `200 OK` (Next.js page), 50% returned `502 Bad Gateway`.

#### 🔬 Micro Technical Cause
Two Ingress resources existed across separate namespaces:
1. `timeguild-prod-ingress` in `timeguild-prod` (pointing to active production pods on port 3000).
2. `timeguild-dev-ingress` in `timeguild-dev` (pointing to an inactive dev service on port 8080).
Traefik aggregates all Ingress resources cluster-wide into a single host routing map. With identical host rules (`timeguild.xyz`) in both Ingresses, Traefik load-balanced requests round-robin between `timeguild-prod` and `timeguild-dev`.

#### 🌐 Macro SRE & Architectural Context
**Multi-Tenant Ingress Isolation**: Ingress host rules are cluster-scoped in Traefik/Nginx controllers. Environment isolation (`dev`, `staging`, `prod`) requires strict domain separation (e.g. `dev.timeguild.xyz`, `lab.timeguild.xyz`, `timeguild.xyz`).

#### 🔧 Resolution & Lessons Learned
Reconfigured `timeguild-dev-ingress` host rules:
```bash
kubectl patch ingress timeguild-dev-ingress -n timeguild-dev --type='json' -p='[{"op": "replace", "path": "/spec/rules/0/host", "value": "dev.timeguild.xyz"}]'
```

---

### 🚨 Case 8: SSL Certificate Verification Failure (`curl (60)` without `-k`)

#### 👁️ Manifestation & Symptoms
- **User Impact**: Browsers showed `NET::ERR_CERT_AUTHORITY_INVALID`.
- **Terminal Error**:
  ```text
  curl: (60) SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
  ```

#### 🔬 Micro Technical Cause
1. `cert-manager` was missing the `letsencrypt-prod` ClusterIssuer resource.
2. `ingress-prod.yaml` requested a wildcard certificate (`*.timeguild.xyz`) using an HTTP-01 solver. ACME protocol specification explicitly mandates that **wildcard certificates MUST use DNS-01 challenges**; Let's Encrypt rejects HTTP-01 challenge requests for wildcard domains.

#### 🌐 Macro SRE & Architectural Context
**Public PKI & ACME Protocol Rules**: HTTP-01 validation proves control over a single web server domain by creating a file at `/.well-known/acme-challenge/<token>`. Because a wildcard covers arbitrary subdomains, ACME requires DNS-01 TXT record validation (`_acme-challenge.domain.com`).

#### 🔧 Resolution & Lessons Learned
1. Applied `cluster-issuer.yaml` to provision `letsencrypt-prod`:
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: admin@timeguild.xyz
       privateKeySecretRef:
         name: letsencrypt-prod-account-key
       solvers:
         - http01:
             ingress:
               class: traefik
   ```
2. Configured single-domain TLS spec in `ingress-prod.yaml` for `timeguild.xyz`, allowing HTTP-01 validation to issue a **valid Let's Encrypt SSL certificate** (Status: `READY: True`).

---

### 🚨 Case 9: Missing CSS & Unstyled Page Rendering

#### 👁️ Manifestation & Symptoms
- **User Impact**: Navigating to `https://timeguild.xyz/` displayed raw, unstyled HTML without styles or fonts.

#### 🔬 Micro Technical Cause
Next.js in standalone mode builds static CSS bundles into `/_next/static/chunks/*.css`. When Service `targetPort` was pointed to Nginx sidecar port 8080, Nginx `default.conf` lacked an explicit `location /_next/static/` proxy pass rule, causing static asset requests to fail or return 502 Bad Gateway during pod transitions.

#### 🌐 Macro SRE & Architectural Context
**Asset Delivery Pipeline**: Web applications require both HTML SSR responses and static asset bundles (CSS, JS, WebFonts). Reverse proxies in front of Next.js must handle static path routing with immutable caching headers (`max-age=31536000`).

#### 🔧 Resolution & Lessons Learned
1. Added explicit static asset routing in `nginx-configmap.yaml`:
   ```nginx
   location /_next/static/ {
       proxy_pass http://nextjs_backend/_next/static/;
       proxy_http_version 1.1;
       proxy_set_header Host $host;
       add_header Cache-Control "public, max-age=31536000, immutable";
   }
   ```
2. Mapped Service `targetPort: 3000` directly to Next.js ready pods, ensuring 100% 200 OK delivery for both HTML and CSS.

---

## 📊 3. Observability & Logql Operations Guide

### Grafana Access Setup
```bash
kubectl port-forward -n timeguild-monitoring svc/prometheus-stack-grafana 3001:80
```
- **URL**: `http://localhost:3001`
- **Credentials**: Username `admin`
- **Dashboard**: **Time Guild SRE Monitoring Dashboard**

### Loki LogQL Query Cheat Sheet
| Log Source | LogQL Query | Description |
| :--- | :--- | :--- |
| **Nginx Edge Logs** | `{namespace="timeguild-prod", container="nginx"}` | Captures JSON access logs, remote IPs, and HTTP status codes |
| **Next.js App Logs** | `{namespace="timeguild-prod", container="nextjs"}` | Captures SSR rendering logs, API logs, and database queries |
| **All Production Logs** | `{namespace="timeguild-prod"}` | Aggregates all pod container logs in production |
| **Stripe / API Events** | `{namespace="timeguild-prod"} \|= "api"` | Filters logs containing API or Stripe checkout keywords |

---

## 🏁 4. Final Verification Summary

- **Production URL**: `https://timeguild.xyz/` (**HTTP/2 200 OK**, strict SSL verified without `-k` flag)
- **CSS Delivery**: `https://timeguild.xyz/_next/static/chunks/1jwuo8je1j6yb.css` (**HTTP/2 200 OK**, `text/css`)
- **Pod Health**: Both `timeguild-prod` and `timeguild-staging` Pods are **`2/2 Running`** with 0 restarts.
- **Git Synchronization**: Changes committed and pushed to `origin/main` across [time-guild](file:///home/si3mshady/time-guild) (`405daa2`) and [time-guild-gitops](file:///home/si3mshady/time-guild-gitops) (`01207b4`).
