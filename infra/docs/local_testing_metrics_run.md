# Local Telemetry Verification Run Report

* **Execution Timestamp**: 2026-07-06T20:50:20Z
* **Tester**: AI DevOps Agent
* **Environment**: Local Development Laboratory (Bun / Next.js)
* **Target Endpoint**: `http://localhost:3000/api/metrics`

---

## 1. Execution Commands & Logs

The dev server was initiated in the workspace root directory:
```bash
bun run dev
```

Terminal outputs during bootstrap:
```text
$ next dev
▲ Next.js 16.2.9 (Turbopack)
- Local: http://localhost:3000
- Environments: .env

[DB] Runtime detected: Node. Loading 'better-sqlite3'...
Database seeded successfully with initial multi-tenant subdomains, creator profiles, and available slots.
```

The metrics endpoint was queried using `curl` from a parallel shell session:
```bash
curl http://localhost:3000/api/metrics
```

---

## 2. Scraping Result Output (Raw Payload)

The HTTP Response Header returned `Content-Type: text/plain; version=0.0.4; charset=utf-8` with status `200 OK`. 

The response body contains the following Prometheus-formatted metrics:

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

## 3. Analysis & Verification Checklist

* [x] **Exposition Format Check**: The payload uses raw plain text format conforming to Prometheus `version=0.0.4` specification.
* [x] **Dynamic DB Integration Check**: The database queries executed by the route returned valid counts (e.g. 1 paid booking, 1 booked slot, 9 available slots, and 5 users).
* [x] **Header Verification Check**: `Cache-Control` header returns `no-store, no-cache`, ensuring Prometheus Operator fetches real-time data instead of cached responses.
* [x] **SRE Alerting Target Check**: Latency metrics and queue depth meters are defined with quantiles and labels ready for PromQL evaluation.
