# Day 15: Nginx Edge Reverse Proxy, TLS/SSL, Rate Limiting, WAF Security & Telemetry

> [!IMPORTANT]
> **Status: CURRENT ACTIVE PHASE (In Progress)**
> *Note: Replaced legacy testing restoration phase with Nginx Edge Proxy, SSL termination, structured logging, rate limiting, and WAF security telemetry.*

---

## 1. Architectural Rationale: Why We Do This
Adding an Nginx edge proxy in front of the Next.js application tier provides an entry barrier to terminate TLS/SSL, enforce rate limits on authentication/checkout APIs, inspect traffic for malicious payloads via Web Application Firewall (WAF) rules, and export structured JSON security telemetry to Loki and Prometheus.
* **Edge SSL/TLS Termination**: Offload TLS encryption and manage SSL certificates at the edge, forwarding sanitized protocol headers (`X-Forwarded-For`, `X-Forwarded-Proto`, `X-Real-IP`).
* **Rate Limiting Zones**: Protect high-value endpoints (`/api/auth/*`, `/api/stripe/*`, `/api/agent/*`) against brute-force attacks and denial-of-service probes.
* **WAF Security Filters**: Inspect request URIs, query strings, headers, and POST payloads for common web vulnerabilities (SQL injection, XSS, directory traversal, bad bot agents).
* **Structured Security Observability**: Format access and security logs into structured JSON payloads, parsing security blocks via Promtail for real-time Grafana dashboard visualization.

---

## 2. Core Implementation Plan

### A. Nginx Configuration & JSON Logging (`infra/docker/nginx/nginx.conf`)
* **JSON Access Log Format**: Configure `log_format json_analytics` to capture IP addresses, HTTP methods, request URIs, response status codes, latency durations, and WAF block flags.
* **Upstream Proxy Pass**: Direct traffic to downstream Next.js application service (`http://app:3000` or K8s Service `timeguild-service:3000`).

### B. Rate-Limiting Zones (`infra/docker/nginx/conf.d/rate-limiting.conf`)
* `limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s`: Enforce strict limits on authentication and user signup routes.
* `limit_req_zone $binary_remote_addr zone=checkout_limit:10m rate=10r/s`: Protect Stripe payment checkout and AI agent scheduling endpoints.
* `limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/s`: General rate limit for standard API calls.

### C. Web Application Firewall (WAF) Rules (`infra/docker/nginx/conf.d/waf-rules.conf`)
* **SQL Injection (SQLi) Protection**: Detect and block common SQL injection patterns (`UNION SELECT`, `OR 1=1`, `--`, `/*`).
* **Cross-Site Scripting (XSS) Protection**: Block `<script>`, `javascript:`, and payload injection attempts.
* **Path Traversal & Probe Shielding**: Reject `../`, `.env`, `wp-admin`, and unauthorized hidden file probes.
* **User-Agent Filtering**: Block known malicious scanners (sqlmap, nikto, dirbuster).

### D. Docker & Helm Manifest Integration
* Create `infra/docker/nginx/Dockerfile` packaging Nginx with custom configuration files and WAF rules.
* Integrate Nginx service container in `infra/compose/docker-compose.yml` and Kubernetes Helm chart manifests.

### E. Promtail Telemetry Parsing & Grafana Security Dashboard
* Configure Promtail pipeline in `infra/logging/promtail-config.yaml` to extract:
  - `nginx_rate_limit_hits_total`
  - `nginx_waf_blocks_total`
  - `nginx_http_requests_total` by status code (`2xx`, `4xx`, `5xx`).
* Add a dedicated **Edge Security & WAF Telemetry** panel grid to Grafana dashboard.

---

## 3. Verification & Testing Steps
1. Verify Nginx container builds and starts cleanly.
2. Test rate-limiting response (`HTTP 429 Too Many Requests`) by sending rapid bursts to `/api/auth/signin`.
3. Test WAF security blocks (`HTTP 403 Forbidden`) using mock injection probes (`curl "/api/creators?id=1%20UNION%20SELECT"`).
4. Verify JSON access logs in Loki and validate Prometheus security metrics.
