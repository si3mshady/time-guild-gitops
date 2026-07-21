# Day 15-a: Nginx Edge Observation Mode, Live Request Rates, WAF Filters & Client IP Telemetry

> [!IMPORTANT]
> **Status: COMPLETED & VERIFIED**

---

## 1. Executive Summary & Objective

In **Day 15-a**, we addressed the Nginx Edge Security Telemetry panels in Grafana to operate in **Observation Mode** (monitor & log without dropping valid connections). This phase enables real-time tracking of:
1. **Incoming Nginx HTTPS Requests/Sec**: Live throughput rates computed dynamically over LogQL log streams.
2. **WAF Security Probes Blocked (`403 Forbidden`)**: Accurate counts of SQL injection, XSS, and scanner probes detected at the Nginx edge.
3. **Rate Limit Hits (`429 Too Many Requests`)**: Counts of rate-limit violations on authentication and checkout routes.
4. **Client IP Address Observation Stream**: Live observation of incoming client IP addresses (`remote_addr`), HTTP methods, request URIs, response status codes, latency durations, and user agents.

---

## 2. Technical Implementation & LogQL Panel Engineering

Rather than relying on static sidecar Prometheus exporter endpoints, Grafana now queries **Loki LogQL streams directly** from Promtail's `container="nginx"` log ingestion pipeline.

### Panel 201: Incoming Nginx HTTPS Requests/Sec
* **Datasource**: Loki
* **LogQL Query**:
  ```logql
  sum(rate({container="nginx"} [1m]))
  ```
* **Visualization**: Timeseries chart displaying real-time incoming request throughput per second.

### Panel 202: WAF Security Probes Blocked (403 Forbidden)
* **Datasource**: Loki
* **LogQL Query**:
  ```logql
  sum(count_over_time({container="nginx"} |= "\"status\":403" [1h]))
  ```
* **Visualization**: Stat panel displaying cumulative security probe blocks over the past 1 hour.

### Panel 203: Rate Limit Hits (429 Too Many Requests)
* **Datasource**: Loki
* **LogQL Query**:
  ```logql
  sum(count_over_time({container="nginx"} |= "\"status\":429" [1h]))
  ```
* **Visualization**: Stat panel displaying cumulative rate-limiting hits over the past 1 hour.

### Panel 204: Live Nginx Edge JSON Access & Security Logs (Observation Mode)
* **Datasource**: Loki
* **LogQL Query**:
  ```logql
  {container="nginx"} | json
  ```
* **Visualization**: Live log stream displaying parsed JSON fields (`remote_addr`, `request_method`, `request_uri`, `status`, `request_time`, `http_user_agent`).

---

## 3. How to Verify Live Telemetry in Grafana

1. **Port-Forward Grafana**:
   ```bash
   kubectl port-forward svc/prometheus-stack-grafana -n timeguild-monitoring 3000:80
   ```
2. **Send Test Batch**:
   ```bash
   ./infra/scripts/generate-nginx-traffic.sh https://127.0.0.1 timeguild.xyz
   ```
3. **View Dashboard**: Open `http://localhost:3000` (User: `admin` / Password: `bnfQ7FgNgeOgdjHHe4kICimyHLpMfbM80Ox9PzG1`) → Navigate to **Time Guild SRE & Nginx Security Monitoring**.
