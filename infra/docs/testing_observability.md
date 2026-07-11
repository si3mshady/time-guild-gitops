# Telemetry & Observability Verification Guide

This document outlines how to test and verify the Prometheus metrics endpoint and log aggregation stack for the **Time Guild / AURA** platform.

---

## 1. Verifying Next.js Metrics Exposition (/api/metrics)

The Next.js application exposes system, database, and transaction metrics in the standard Prometheus text format.

### Step A: Start the Next.js Server
Ensure the development or production server is running:
```bash
# Start in development mode
bun run dev

# Or start in compiled production mode
bun run build && bun run start
```

### Step B: Scrape the Endpoint Locally
Query the endpoint using `curl` to verify it generates the Prometheus text output:
```bash
curl http://localhost:3000/api/metrics
```

### Expected Output Payload:
```text
# HELP timeguild_bookings_total Total bookings by status.
# TYPE timeguild_bookings_total counter
timeguild_bookings_total{status="paid"} 1

# HELP timeguild_booking_revenue_dollars_total Total revenue collected by booking status.
# TYPE timeguild_booking_revenue_dollars_total counter
timeguild_booking_revenue_dollars_total{status="paid"} 200

# HELP timeguild_stripe_transfers_completed_total Total successful Stripe Connect transfers executed.
# TYPE timeguild_stripe_transfers_completed_total counter
timeguild_stripe_transfers_completed_total 1

# HELP timeguild_stripe_escrow_refunds_total Total refunds executed due to cancellations or no-shows.
# TYPE timeguild_stripe_escrow_refunds_total counter
timeguild_stripe_escrow_refunds_total 0

# HELP timeguild_slots_total Total consulting availability slots by status.
# TYPE timeguild_slots_total gauge
timeguild_slots_total{status="available"} 9
timeguild_slots_total{status="booked"} 1

# HELP timeguild_users_total Total users onboarded on the trust layer platform.
# TYPE timeguild_users_total gauge
timeguild_users_total{role="client"} 1
timeguild_users_total{role="creator"} 4

# HELP timeguild_http_request_duration_seconds P95 web request response latency in seconds.
# TYPE timeguild_http_request_duration_seconds gauge
timeguild_http_request_duration_seconds{quantile="0.95"} 0.145

# HELP timeguild_db_query_duration_seconds Average SQL prepared statement execution duration in seconds.
# TYPE timeguild_db_query_duration_seconds gauge
timeguild_db_query_duration_seconds 0.005

# HELP timeguild_bullmq_queue_depth Active background jobs queued in Redis database.
# TYPE timeguild_bullmq_queue_depth gauge
timeguild_bullmq_queue_depth{queue="stripe-payouts"} 0
```

---

## 2. Testing Cluster Scraping (Kubernetes/k3s)

Once deployed to Kubernetes, Prometheus scrapes the app pods automatically.

### Step A: Apply the ServiceMonitor
Apply the ServiceMonitor resource to register the endpoint with the Prometheus Operator:
```bash
kubectl apply -f infra/monitoring/prometheus-servicemonitor.yaml
```

### Step B: Validate Prometheus Targets
1. Port-forward the Prometheus dashboard:
   ```bash
   kubectl port-forward svc/prometheus-stack-kube-prom-prometheus -n timeguild-monitoring 9090
   ```
2. Navigate to `http://localhost:9090/targets` in a browser.
3. Search for the `timeguild-monitor` target and verify that its status is **UP**.

---

## 3. Querying Centralized Logs (Loki & Promtail)

Verify that Promtail is collecting and shipping logs to Loki.

### Step A: Open Grafana
1. Retrieve the Grafana admin password:
   ```bash
   kubectl --namespace timeguild-monitoring get secrets prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
   ```
2. Port-forward Grafana:
   ```bash
   kubectl port-forward svc/prometheus-stack-grafana -n timeguild-monitoring 3000:80
   ```

### Step B: Run Log Queries
1. Navigate to Grafana at `http://localhost:3000` (User: `admin`).
2. Go to **Explore** from the sidebar.
3. Select the **Loki** data source.
4. Input a LogQL query to search Next.js logs:
   ```logql
   {app="timeguild"} |= "Stripe"
   ```
5. Click **Run query** to view the live log stream.
