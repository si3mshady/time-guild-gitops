# Day 16: Nginx Edge Reverse Proxy, Rate Limiting, & WAF Security Telemetry

> [!WARNING]
> **Status: OUTSTANDING (Future Phase)**

---

## 1. Architectural Rationale: Why We Do This
Adding Nginx as an edge ingress or reverse proxy layer provides an entry point to filter malicious traffic, enforce rate limits on authentication/checkout APIs, and generate structured security logs.
* **Edge Rate Limiting**: Block denial-of-service attempts and brute-force attacks at the Nginx edge before they consume downstream Next.js CPU cycles.
* **WAF Security & Blocking**: Filter common web vulnerabilities (SQL injection, XSS, automated path probing) using lightweight security rule engines.
* **Security Observability**: Turn blocked requests, rate-limit hits, and auth failures into structured JSON logs, forwarding them via Promtail/Loki and exposing counters for Grafana visualization.

---

## 2. Core Tasks

### A. Deploy Nginx Reverse Proxy with TLS
* Configure Nginx to route incoming traffic (e.g. `*.timeguild.xyz`) to the Kubernetes Traefik Ingress or Next.js services.
* Enable TLS termination using certs managed via cert-manager, forwarding downstream protocol headers (`X-Forwarded-For`, `X-Forwarded-Proto`).

### B. Configure Rate-Limiting Zones
Implement Nginx rate-limiting on sensitive API endpoints:
* Create a `limit_req_zone` keyed by client IP (`$binary_remote_addr`) for authentication paths (`/api/auth/signin`, `/api/auth/signup`).
* Configure request burst buffers and delay structures to block high-frequency probes while allowing legitimate traffic bursts.

### C. Deploy Web Application Firewall (WAF)
* Enable a lightweight WAF (such as ModSecurity or OWASP Coraza Core Rule Set) running on the Nginx edge.
* Enforce rules to detect malicious payloads, scanner signatures, and directory traversal attempts.

### D. Export Security Telemetry to Loki & Prometheus
* Configure Nginx to output access and security block logs in structured JSON format.
* Set up Promtail to parse Nginx logs, automatically extracting metrics:
  - `nginx_rate_limit_hits_total`: Count of requests blocked/delayed by rate limits.
  - `nginx_waf_blocks_total`: Count of requests blocked by security rule matches.
  - `nginx_auth_failures_total`: Spikes in 401/403 responses on auth routes.
  - `nginx_ip_violations_total`: Top source IPs blocked.

### E. Build Grafana Security Telemetry Dashboard
* Add a dedicated Grafana dashboard visualizing live edge request counts, rate-limit hit rates, WAF blocked payloads, and 4xx/5xx status ratios.
* Set up alerting thresholds to trigger alert notification notifications if rate-limit hits exceed expected baselines.

---

## 3. Study & Reference Materials
* **NGINX Rate Limiting Guide**: In-depth configurations for rate-limiting zones:  
  [https://www.nginx.com/blog/rate-limiting-nginx/](https://www.nginx.com/blog/rate-limiting-nginx/)
* **Nginx WAF & ModSecurity Integration**: Setting up security rule engines on Nginx:  
  [https://github.com/SpiderLabs/ModSecurity-nginx](https://github.com/SpiderLabs/ModSecurity-nginx)
* **Parsing Nginx Logs with Promtail/Loki**: Extracting structured telemetry from access logs:  
  [https://grafana.com/docs/loki/latest/send-data/promtail/](https://grafana.com/docs/loki/latest/send-data/promtail/)
