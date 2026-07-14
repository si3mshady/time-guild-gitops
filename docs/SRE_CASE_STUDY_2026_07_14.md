# SRE Case Study: Observability Stabilization & Authentication Failures
**Date:** July 14, 2026  
**Context:** Time Guild (TimeWorth) Multi-Tenant Platform

---

## 1. Executive Summary

This case study documents the end-to-end troubleshooting of two critical system failures on the Time Guild platform:
1. **Observability Failure (Datasource Crash & Log Ingest Gap):** Grafana was in a crash loop due to provisioning conflicts, and Loki logs were missing tenant tags due to an incomplete Promtail relabeling configuration.
2. **Onboarding Authentication Failure (Signup Loop):** Users registering on the platform could not log in and were silently redirected back to the `/auth` page because browsers rejected the session cookie.

By debugging across the entire stack—from Next.js source code to Promtail configuration secrets and Kubernetes namespace resources—both issues were resolved, resulting in a single-pane-of-glass dashboard that segment logs and metrics dynamically per tenant.

---

## 2. Macro Recap (The System & Architectural View)

The macro view explores how the components interact at the network and cluster level to route traffic, aggregate logs, and expose metrics.

```text
                                [Ingress: Traefik (Port 80/443)]
                                               │
                       ┌───────────────────────┴───────────────────────┐
                       ▼                                               ▼
         [Namespace: timeguild-dev]                       [Namespace: tenant-jen]
         [Service: timeguild-dev-service]                 [Service: timeguild-app-service]
                       │                                               │
                       ▼                                               ▼
         [Next.js App Pod (Dev)]                          [Next.js App Pod (Tenant)]
          Exposes /api/metrics                             Exposes /api/metrics
                       │                                               │
                       ├───────────────────────┬───────────────────────┤
                       ▼                       ▼                       ▼
               [ServiceMonitor]        [Promtail DaemonSet]      [Sqlite DB File]
                       │                       │                (Shared HostPath)
                       ▼                       ▼
              [Prometheus Server]        [Grafana Loki]
                       │                       │
                       └───────────┬───────────┘
                                   ▼
                            [Grafana Dashboard]
```

### A. Grafana Datasource Conflict
* **Why it happened:** Grafana restricts datasource provisioning such that only **one** datasource can be marked as `isDefault: true` per organization. In the cluster configuration, the Prometheus Helm chart declared Prometheus as default, while the Loki stack Helm chart declared Loki as default. This caused the Grafana provisioning engine to throw an unrecoverable validation error and crash the pod.
* **The Fix:** We patched the Loki ConfigMap (`loki-stack`) data section, changing `isDefault: true` to `isDefault: false`, and performed a rollout restart of the Grafana deployment.

### B. Promtail Path & Label Mismatch
* **Why it happened:** The original Promtail config set up a secondary scraping job named `kubernetes-pods-tenant` to scrape tenant namespaces (`tenant-(.*)`). However, it did not specify a target file path (`__path__` rule). As a result, Promtail had no target files to read from, and no tenant logs were ever sent to Loki.
* **The Fix:** We consolidated the scraping config into a single `kubernetes-pods` job. We added a relabeling rule that checks the pod's namespace. If the namespace matches `tenant-(.*)`, it extracts the subdomain name and applies it as a `tenant` label. If the namespace is a platform environment (e.g. `timeguild-dev`), it applies `tenant="platform"`.

### C. Missing Kubernetes Secrets in Staging
* **Why it happened:** The staging environment deployment (`timeguild-staging` namespace) was stuck in `CreateContainerConfigError` because the Helm charts referenced a secret named `timeguild-staging-env-secrets` that did not exist.
* **The Fix:** We executed the secret sync script to parse the local `.env` file and generate the Kubernetes secret inside the `timeguild-staging` namespace, resolving the rollout blocker.

---

## 3. Micro Recap (The Code & Protocol View)

The micro view analyzes how web standards, code execution, and browser security behaviors caused the silent onboarding failure.

### A. The Cookie Secure Attribute Mismatch
* **Why it happened:** The Next.js backend cookie setting for `tw_session` was configured as:
  ```typescript
  secure: process.env.NODE_ENV === "production"
  ```
  In the containerized cluster, the application runs with `NODE_ENV=production`, resolving `secure` to `true`.
  The `Secure` attribute instructs the browser to only transmit the cookie over encrypted connections (HTTPS). However, because the development and staging ingress route requests over plain HTTP (`http://timeguild.xyz` or `http://timeguild.lab`) to bypass SSL certificate handshake failures, the browser flagged the plain HTTP response and refused to store the cookie.
* **The Fix:** We modified the server-side cookie setting in [auth-server.ts](file:///home/si3mshady/time-guild/src/lib/auth-server.ts) to force `secure: false`, ensuring browsers accept the session cookie in HTTP testing clusters.

### B. The Onboarding Redirect Loop
* **Why it happened:** 
  1. The signup API route successfully created the user and returned a `200 OK` response.
  2. Because of the `secure: true` mismatch, the browser discarded the session cookie.
  3. The frontend routed the user to `/onboarding`.
  4. The `/onboarding` page loaded and initiated a client-side hook check (`useAuth`) which queried the server for the current session.
  5. The server returned `user: null` because the browser did not attach the session cookie.
  6. The `/onboarding` page redirected the unauthenticated client back to `/auth` (signup page) immediately:
     ```typescript
     useEffect(() => {
       if (!loading && !user) {
         router.push("/auth");
       }
     }, [user, loading, router]);
     ```

### C. Next.js Client-Side Request Caching & Role Update Lag
* **Why it happened:** Next.js and web browsers cache `GET` requests (such as `/api/auth/user`) by default to improve navigation performance. When a user signed up, their role was initialized as `"client"`. Clicking "Earn from my time" successfully updated the database role to `"creator"`, but subsequent `refreshUser()` calls used the browser's **cached GET response** showing `"client"`. The UI remained stuck on the role selection screen because it never realized the role had updated.
* **The Fix:** We disabled caching on the user session query by adding `{ cache: "no-store" }` to the client-side `fetch` options in [auth-provider.tsx](file:///home/si3mshady/time-guild/src/components/auth-provider.tsx) and returning `Cache-Control: no-store, max-age=0, must-revalidate` in [route.ts (user session)](file:///home/si3mshady/time-guild/src/app/api/auth/user/route.ts).

---

## 4. Skills Inventory for Troubleshooting

To solve similar distributed systems bugs, SRE and DevOps engineers must master the following skills:

### 🛠️ Skill 1: Log & Configuration Auditing
* **Tooling:** `kubectl logs`, `kubectl describe`, ConfigMap/Secret inspection.
* **How it was applied:** We read container-specific logs (`-c grafana` inside a 3-container pod) to isolate the datasource provisioning error, and base64-decoded the Promtail configuration secret to audit the relabel rules.

### 🛠️ Skill 2: Kubernetes Network Traffic Routing
* **Tooling:** Ingress Class controllers, Service definitions, endpoints verification.
* **How it was applied:** We identified that the staging deployment was dead by querying `kubectl get endpoints` and tracking down the namespace configuration errors.

### 🛠️ Skill 3: Web Security & Protocol Engineering
* **Concepts:** RFC 6265 Cookie management, reverse-proxy headers (`X-Forwarded-Proto`, `X-Forwarded-Host`).
* **How it was applied:** We diagnosed the missing cookie by mapping the relationship between plain-HTTP Traefik ingress and browser-side `Secure` cookie constraints.

### 🛠️ Skill 4: Prometheus Metric Exposition & Scraping
* **Concepts:** ServiceMonitor declarations, Prometheus dynamic metrics target matching.
* **How it was applied:** We mapped the dynamically provisioned tenant subdomains to metrics output variables, ensuring latency panels do not break when filtering.

---

## 5. Precursor Knowledge Map

To build a strong foundation, study the following topics:

| Topic | Precursor Concept | Why it Matters here |
| :--- | :--- | :--- |
| **HTTP Protocol** | Session Cookies & Headers | Understands how `Set-Cookie` directives change browser state. |
| **Container Networking** | Reverse Proxying & Port Mapping | Understands how Traefik maps external HTTP requests to internal port 80. |
| **Prometheus Config** | Scrape configs and metric labels | Understands how PromQL query filters `{tenant="..."}` resolve targets. |
| **Log Relabeling** | RegEx and Regex Capture groups | Allows parsing metadata fields (like Namespace) into searchable index tags. |
| **Distributed Tracing** | W3C headers (`traceparent`) | Allows tracing requests across client, server middleware, and logs. |
