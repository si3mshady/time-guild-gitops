# Day 15: Nginx Edge Reverse Proxy, TLS/SSL, Rate Limiting, WAF Security & Telemetry

> [!IMPORTANT]
> **Status: COMPLETED & VERIFIED (Includes Day 15-a Telemetry & Panel Fixes)**
> *For a full macro/micro architectural deep-dive, sidecar pattern explanation, TLS certificate flow, and troubleshooting playbook, see [NGINX_GITOPS_OBSERVABILITY_COURSE_GUIDE.md](file:///home/si3mshady/time-guild/docs/learning-resources/NGINX_GITOPS_OBSERVABILITY_COURSE_GUIDE.md).*

---

## 1. Architectural Rationale: Why We Do This
Adding an Nginx edge proxy in front of the Next.js application tier provides an entry barrier to terminate TLS/SSL, enforce rate limits on authentication/checkout APIs, inspect traffic for malicious payloads via Web Application Firewall (WAF) rules, and export structured JSON security telemetry to Loki and Prometheus.
* **Edge SSL/TLS Termination**: Offload TLS encryption and manage SSL certificates at the edge, forwarding sanitized protocol headers (`X-Forwarded-For`, `X-Forwarded-Proto`, `X-Real-IP`).
* **Rate Limiting Zones**: Protect high-value endpoints (`/api/auth/*`, `/api/stripe/*`, `/api/agent/*`) against brute-force attacks and denial-of-service probes.
* **WAF Security Filters**: Inspect request URIs, query strings, headers, and POST payloads for common web vulnerabilities (SQL injection, XSS, directory traversal, bad bot agents).
* **Structured Security Observability**: Format access and security logs into structured JSON payloads, parsing security blocks via Promtail for real-time Grafana dashboard visualization.

---

## 2. Core Implementation & Observation Mode (Day 15-a Integration)

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

### D. Promtail Telemetry Parsing & Grafana Security Dashboard
* Configure Promtail pipeline in `infra/logging/promtail-config.yaml` to extract container logs tagged with `container="nginx"`.
* **Panel 201**: *Incoming Nginx HTTPS Requests/Sec* (`sum(rate({container="nginx"}[1m]))`, `type: stat`, `graphMode: area`).
* **Panel 202**: *WAF Security Probes Blocked (403 Forbidden)* (`sum(count_over_time({container="nginx"} |= "\"status\":403" [1h]))`).
* **Panel 203**: *Rate Limit Hits (429 Too Many Requests)* (`sum(count_over_time({container="nginx"} |= "\"status\":429" [1h]))`).
* **Panel 204**: *Live Nginx Edge JSON Access & Security Logs Stream* (`{container="nginx"} | json`).

---

## 3. Deep-Dive Case Study: Resolving the Grafana Vector Label Collision

During Day 15-a, we encountered a persistent Grafana panel error:
> `execution vector cannot contain metrics with the same labelset` (indicated by a red square / exclamation triangle on Panel 201).

### Root Cause Analysis
1. **Plugin Type Mismatch**: Panel 201 was created as a Grafana `timeseries` panel (`"type": "timeseries"`). When querying Loki for a range vector without stripping all stream labels (`stream="stdout"`, `stream="stderr"`), Loki returned multiple matrix streams. Grafana's `timeseries` plugin failed to collapse the matrix streams into a single timeseries vector, throwing the label collision error.
2. **The Resolution**: Converted Panel 201 to `"type": "stat"` with `"graphMode": "area"` and `"queryType": "range"`, matching the proven configuration of Panels 202 and 203.

```json
{
  "id": 201,
  "title": "Incoming Nginx HTTPS Requests/Sec",
  "type": "stat",
  "options": {
    "colorMode": "value",
    "graphMode": "area",
    "justifyMode": "auto"
  },
  "targets": [
    {
      "datasource": { "type": "loki", "uid": "Loki" },
      "expr": "sum(rate({container=\"nginx\"}[1m]))",
      "legendFormat": "Requests/sec",
      "queryType": "range"
    }
  ]
}
```

---

## 4. Verification & Testing Steps
1. Verify Nginx container builds and starts cleanly in Pod sandbox.
2. Test rate-limiting response (`HTTP 429 Too Many Requests`) by sending rapid bursts to `/api/auth/signin`.
3. Test WAF security blocks (`HTTP 403 Forbidden`) using mock injection probes (`curl "/api/creators?id=1%20UNION%20SELECT"`).
4. Verify live JSON access logs in Loki and confirm all Grafana Edge Telemetry panels display cleanly without any red exclamation triangles.
