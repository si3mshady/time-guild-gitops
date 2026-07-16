# Day 9 Grafana Metrics & Namespace Isolation Fix - 2026-07-16

## 1. Problem Statement
The Grafana dashboard displayed incorrect metrics for total bookings, escrow revenues, and available slots:
* **Mismatched Bookings / Revenue**: The dashboard displayed `Total Bookings: 2` and `Total Escrow Revenue: 200 USD`, when in reality the database contained only **1 booking** at a rate of **100 USD**.
* **Inflated Slots Count**: The slots availability count displayed over `500` slots, when the database had only 9 available and 1 booked slot.

## 2. Root Cause Analysis
Kubernetes runs multiple environments/namespaces concurrently:
* `timeguild-dev` (Development pod)
* `timeguild-staging` (Staging pod)
* `timeguild-prod` (Production pod)
* `tenant-si3mshady` (Tenant pod)

Each of these pods exposes application metrics via `/api/metrics`.
Because the Grafana dashboard panels used global aggregation queries without environment filtering (e.g., `sum(timeguild_bookings_total{tenant=~"$tenant"})`), Prometheus summed the metrics across all pods in all namespaces together. This metrics collision resulted in inflated statistics.

## 3. Implementation Details
We introduced a namespace selection template variable and updated the PromQL expressions across the dashboard ConfigMap:

### A. Template Variable Addition
Added a `$namespace` query variable to fetch all active namespaces from the `timeguild_users_total` timeseries:
```json
{
  "name": "namespace",
  "query": "label_values(timeguild_users_total, namespace)",
  "type": "query"
}
```

And updated the `$tenant` variable to query only tenants belonging to the selected namespace:
```json
{
  "name": "tenant",
  "query": "label_values(timeguild_users_total{namespace=~\"$namespace\"}, tenant)",
  "type": "query"
}
```

### B. Panel Query Filters
Updated all panels to include the `{namespace=~"$namespace"}` filter:
1. **Total Bookings**:
   `sum(timeguild_bookings_total{namespace=~\"$namespace\",tenant=~\"$tenant\"})`
2. **Total Escrow Revenue**:
   `sum(timeguild_booking_revenue_dollars_total{namespace=~\"$namespace\",tenant=~\"$tenant\"})`
3. **Completed Stripe Transfers**:
   `sum(timeguild_stripe_transfers_completed_total{namespace=~\"$namespace\",tenant=~\"$tenant\"})`
4. **Stripe Refunds / Cancellations**:
   `sum(timeguild_stripe_escrow_refunds_total{namespace=~\"$namespace\",tenant=~\"$tenant\"})`
5. **Active BullMQ Queue Depth**:
   `timeguild_bullmq_queue_depth{namespace=~\"$namespace\"}`
6. **Consulting Slot Availability Status**:
   `timeguild_slots_total{namespace=~\"$namespace\",tenant=~\"$tenant\"}`
7. **HTTP / DB Latencies**:
   `timeguild_http_request_duration_seconds_p95{namespace=~\"$namespace\",tenant=~\"$tenant\"}`
   `timeguild_db_query_duration_seconds{namespace=~\"$namespace\",tenant=~\"$tenant\"}`
8. **Real-time Container Logs**:
   `{namespace=~\"$namespace\"}` (simplified because Promtail namespace relabeling only attaches the `tenant` label to tenant namespaces matching `tenant-(.*)`, so querying by namespace directly is the most robust way to support both dev and customer logs)

## 4. How to Verify
1. Open Grafana at `http://localhost:3000`.
2. Select the `namespace` dropdown at the top-left (choose `timeguild-dev` or `tenant-si3mshady`).
3. Select the appropriate `tenant` from the dropdown list.
4. Verify that the stats match the database values.
