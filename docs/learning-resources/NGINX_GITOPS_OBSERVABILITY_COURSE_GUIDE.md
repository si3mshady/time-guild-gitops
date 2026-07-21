# Deep Dive: Nginx Sidecar, TLS Termination, GitOps, & Observability Architecture

This guide provides a comprehensive, production-grade technical breakdown of the **Nginx Edge Reverse Proxy Sidecar**, **Let's Encrypt TLS Automation**, **Kubernetes Network Policies**, and **Prometheus/Loki/Grafana Observability Stack** implemented in the Time Guild application.

---

## 1. Executive Architecture Overview

```text
[ Client Request ] ──(HTTPS :443)──► [ Traefik Ingress Controller ]
                                              │ (TLS Terminated via cert-manager / Let's Encrypt)
                                              ▼ (Plain HTTP :80)
                                     [ K8s Service: timeguild-prod-service ]
                                              │ (Port 80 -> TargetPort 8080)
                                              ▼
                        ┌─────────────────────────────────────────────────────────┐
                        │ Kubernetes Pod (Namespace: timeguild-prod)             │
                        │ Shared Network Namespace (localhost)                    │
                        │                                                         │
                        │  ┌──────────────────────┐    ┌───────────────────────┐  │
                        │  │ Container: nginx     │───►│ Container: nextjs     │  │
                        │  │ (Listens on :8080)   │    │ (Listens on :3000)    │  │
                        │  │ - WAF Filters        │    │ - Bun Runtime         │  │
                        │  │ - Rate Limiting      │    │ - Next.js App Router  │  │
                        │  │ - JSON Access Logs   │    │ - SQLite Database     │  │
                        │  └──────────┬───────────┘    └───────────────────────┘  │
                        └─────────────┼───────────────────────────────────────────┘
                                      │ (stdout JSON log stream)
                                      ▼
                        [ Promtail DaemonSet Scraper ]
                                      │
                                      ▼
                        [ Loki Log Storage Engine ] ──► [ Grafana Dashboard ]
```

---

## 2. Root Cause Analysis: Problems Encountered & Engineering Solutions

During the deployment of the Nginx sidecar architecture on Day 15, we encountered 4 critical failure modes that blocked traffic and obscured telemetry. Understanding these failure modes is vital for mastering Kubernetes networking and observability.

### Issue 1: Kubernetes NetworkPolicy Port Drop (The Silent 502)
* **Root Cause**: The Kubernetes `NetworkPolicy` (`timeguild-prod-netpolicy`) was configured to allow ingress traffic **only on port 80**. When Traefik attempted to forward HTTP requests to `targetPort: 8080` (the Nginx sidecar container), the Linux kernel `iptables` / `eBPF` rules managed by the Kubernetes CNI dropped the TCP handshake packets, returning an immediate `502 Bad Gateway` at the ingress edge.
* **Micro Breakdown**: NetworkPolicy rules apply to the Pod network interface (`eth0`). Even though the Pod selector matched, traffic arriving on port `8080` was dropped before reaching Nginx process sockets.
* **Resolution**: Updated the `NetworkPolicy` ingress specification to explicitly permit ports `80`, `8080`, and `3000`:
  ```yaml
  ingress:
    - ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 3000
  ```

### Issue 2: Service TargetPort Misconfiguration (Sidecar Bypass)
* **Root Cause**: The Kubernetes Service `timeguild-prod-service` had `targetPort: 3000`. Traffic arriving at the Service was sent directly to the Next.js container on port `3000`, completely bypassing the Nginx sidecar container on port `8080`.
* **Consequence**: Nginx received 0 requests, generated 0 access logs, and triggered no WAF or rate-limiting rules.
* **Resolution**: Patched `timeguild-prod-service` to map `port: 80` -> `targetPort: 8080`, ensuring all incoming ingress requests pass through Nginx first.

### Issue 3: Ingress Host Rule Collisions
* **Root Cause**: Both `timeguild-dev-ingress` (in `timeguild-dev` namespace) and `timeguild-prod-ingress` (in `timeguild-prod` namespace) specified rules for `host: timeguild.xyz`. `timeguild-dev-ingress` lacked a valid TLS `secretName` reference in its `spec.tls` block. When Traefik evaluated incoming HTTPS SNI requests for `timeguild.xyz`, it randomly selected the unencrypted/unconfigured ingress router, resulting in TLS handshake failures and 502 errors.
* **Resolution**: Reconfigured `timeguild-dev-ingress` to use hostname `dev.timeguild.xyz` and ensured `timeguild-prod-ingress` has exclusive ownership of `timeguild.xyz` with `secretName: timeguild-prod-tls`.

### Issue 4: Grafana LogQL Label Mismatch
* **Root Cause**: The Grafana dashboard panel LogQL query was hardcoded to `{app=~".*nginx.*"} | json`. Promtail automatically attaches standard labels `namespace`, `pod`, and `container` to log streams. Because the container name was `nginx`, `{app=...}` matched zero Loki streams.
* **Resolution**: Updated the LogQL panel expression to `{container="nginx"} | json`, instantly rendering live JSON access and security logs in Grafana.

---

## 3. The Kubernetes Sidecar Pattern (Micro vs. Macro)

### What is the Sidecar Pattern?
In Kubernetes, a **Pod** is the smallest deployable unit and can contain one or more containers that share:
1. **Network Namespace**: Containers inside the same Pod share `IP address`, `network interface`, and `localhost` port space.
2. **IPC Namespace**: Containers can communicate via System V IPC or POSIX shared memory.
3. **Storage Volumes**: Volumes mounted into a Pod are accessible by all containers in that Pod.

### Micro Technical View (Inside the Pod)
* Container A (`nextjs`): Runs Bun/Node.js, listens on `127.0.0.1:3000`. It focuses strictly on application business logic, database queries, and rendering Next.js pages.
* Container B (`nginx`): Runs Nginx 1.25 Alpine, listens on `0.0.0.0:8080`. It receives external HTTP traffic from the cluster network and proxies requests internally to `http://127.0.0.1:3000` via loopback.
* **Communication Overhead**: Near ZERO latencies (~0.1ms) because proxying from Nginx to Next.js happens over the local loopback interface (`lo` / `127.0.0.1`) without leaving the Pod sandbox.

### Macro Technical View (System & Platform Engineering)
* **Separation of Concerns**: Developers write business logic in Next.js without polluting app code with WAF rule enforcement, Nginx rate-limiting syntax, or low-level HTTP header filtering.
* **Independent Scalability & Updates**: Nginx security rules and proxy configurations can be updated via Kubernetes ConfigMaps without needing to recompile or rebuild the main Next.js Docker image.
* **Security Guardrail (Zero Trust Edge)**: Nginx acts as a local shield. Malicious payloads (SQL injection, XSS probes, path traversal) are rejected at the Nginx process boundary before hitting Node/Bun event loops.

---

## 4. TLS/SSL & Certificate Management Workflow

The interaction between **Let's Encrypt**, **cert-manager**, **Traefik**, and **Nginx** represents the modern Kubernetes edge security pipeline.

```text
[ User Browser ]
       │
       │ 1. HTTPS Request (SNI: timeguild.xyz)
       ▼
[ Traefik Ingress Controller ] ◄── 4. Reads Secret "timeguild-prod-tls"
       │
       │ 3. Issues Valid X.509 Certificate
       ▼
[ cert-manager Operator ] ◄──► [ Let's Encrypt ACME Server ]
       │                        (HTTP-01 Challenge on /.well-known/acme-challenge/)
       │
       │ 5. Decrypts TLS & Forwards Plain HTTP
       ▼
[ Nginx Sidecar (:8080) ]
       │
       │ 6. Reverse Proxy to 127.0.0.1:3000
       ▼
[ Next.js Application Engine ]
```

### Detailed Workflow Steps:
1. **Ingress Annotation**: `timeguild-prod-ingress` includes the annotation `cert-manager.io/cluster-issuer: letsencrypt-prod`.
2. **Certificate Request Generation**: `cert-manager` detects the annotation and automatically creates a `Certificate` and `CertificateRequest` resource.
3. **ACME Challenge Execution**: `cert-manager` contacts Let's Encrypt ACME API servers. Let's Encrypt requests an **HTTP-01 Challenge**. `cert-manager` provisions a temporary pod and ingress route for `http://timeguild.xyz/.well-known/acme-challenge/<token>`.
4. **Validation & Secret Provisioning**: Let's Encrypt verifies the domain ownership over HTTP. Upon validation, Let's Encrypt issues a signed X.509 TLS certificate. `cert-manager` saves the certificate and private key into Kubernetes Secret `timeguild-prod-tls`.
5. **TLS Termination at Traefik**: Traefik reads `timeguild-prod-tls`, terminates TLS at the cluster entry point (port 443), and injects downstream headers (`X-Forwarded-For`, `X-Forwarded-Proto: https`, `X-Real-IP`).
6. **Internal Plaintext Delivery**: Traefik forwards sanitized HTTP traffic over the secure internal cluster network to `timeguild-prod-service:80` -> Nginx sidecar `8080` -> Next.js `3000`.

---

## 5. Observability Pipeline: Nginx JSON Logs -> Promtail -> Loki -> Grafana

### Step 1: Nginx JSON Log Formatting (`nginx.conf`)
Nginx outputs structured JSON access logs directly to `/dev/stdout`:
```nginx
log_format json_analytics escape=json
  '{"time_local":"$time_local",'
  '"remote_addr":"$remote_addr",'
  '"request_method":"$request_method",'
  '"request_uri":"$request_uri",'
  '"status":$status,'
  '"body_bytes_sent":$body_bytes_sent,'
  '"request_time":$request_time,'
  '"http_referrer":"$http_referer",'
  '"http_user_agent":"$http_user_agent"}';

access_log /dev/stdout json_analytics;
```

### Step 2: Promtail Log Ingestion
Promtail runs as a Kubernetes `DaemonSet` on every node, tailing container stdout logs from `/var/log/pods/*/*/*.log`. It automatically attaches Kubernetes metadata labels:
* `namespace="timeguild-prod"`
* `pod="timeguild-prod-75894b88cf-77gk6"`
* `container="nginx"`

### Step 3: Loki Indexing & Storage
Promtail pushes log batches to Loki via HTTP (`http://loki-stack:3100/loki/api/v1/push`). Loki indexes the labels and stores log line payloads compressed.

### Step 4: Grafana Visualization
Grafana queries Loki using LogQL:
* **Log Stream Panel**: `{container="nginx"} | json`
* **Filtering WAF Blocks**: `{container="nginx"} | json | status = 403`
* **Filtering Rate Limits**: `{container="nginx"} | json | status = 429`

---

## 6. SRE Verification Commands Playbook

```bash
# 1. Test HTTPS endpoint & TLS certificate issuer
curl -sS -vk --resolve timeguild.xyz:443:127.0.0.1 https://timeguild.xyz/ | head -n 15

# 2. Verify Nginx sidecar listening ports inside Pod
kubectl exec -n timeguild-prod deploy/timeguild-prod -c nginx -- netstat -tlpn

# 3. Test NetworkPolicy ingress connectivity from Traefik
kubectl exec -n kube-system deploy/traefik -- wget -qO- http://timeguild-prod-service.timeguild-prod.svc.cluster.local:80/

# 4. Generate synthetic WAF & rate-limiting traffic
./infra/scripts/generate-nginx-traffic.sh https://127.0.0.1 timeguild.xyz

# 5. Query Loki API directly for Nginx logs
kubectl exec -n timeguild-monitoring deploy/prometheus-stack-grafana -c grafana -- \
  wget -qO- "http://loki-stack:3100/loki/api/v1/query_range?query=%7Bcontainer%3D%22nginx%22%7D&limit=5"
```
