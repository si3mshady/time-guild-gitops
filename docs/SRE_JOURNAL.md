# SRE Journal & Log - Infrastructure & GitOps Repository

## 1. Discovery Phase & Architecture Inventory

### Tech Stack Identification
* **Frontend Framework:** Next.js 16 (App Router)
* **Backend Runtime:** Node.js / Bun (Runtime-dynamic SQLite loader, currently executing under Bun 1.3.14 in alpine container).
* **Database:** SQLite (`time_worth.db`) mounted via hostPath `/var/lib/timeguild/data-dev` into the containers.
* **Payment Layer:** Stripe SDK (Checkout Sessions, Connect Express onboarding, Transfers, Webhooks).
* **AI Layer:** DeepSeek API via custom chat router for dynamic agent pre-qualification.
* **Network Entrypoint:** External Traffic -> static AWS Elastic IP -> Traefik Ingress Controller (ports 80/443) -> Traefik Ingress routes (`Host("timeguild.xyz")` and dynamic exact-hosts `Host("username.timeguild.xyz")` with priority `10000`) -> Cluster IP Service (port 80) -> Next.js container (running as non-root UID `1001` on port 80).

### The Critical Path (Transactions that CANNOT fail)
1. **Stripe Checkout Session Creation:** Initiating a booking and redirecting to Stripe payment page.
2. **Stripe Webhook Capture:** Webhook receiving `payment_intent.succeeded` -> atomic transition of booking status to `confirmed` and slot status to `booked`.
3. **Session Completion & Payout Transfer:** PIN verification (`verifySessionPIN`) and automatic trigger of `stripe.transfers.create` to transfer the 85% creator payout share to the connected Express account.
4. **Rescheduling & Cancellation Refunds:** Automated trust rules (`cancelBooking`) executing refunds via `stripe.refunds.create` (100% refund for 24h+ notice or no-show).

### Tolerable Paths (Non-blocking or asynchronous)
1. **AI Screening Chat Logs:** Client-agent dialogue history (`chat_messages` table).
2. **Review & Ratings:** Review submissions (`reviews` table).
3. **Availability Management:** Slot creation (`slots` table).

### Target Observability Backend
* **Metrics:** Prometheus Operator (`kube-prometheus-stack` in `timeguild-monitoring` namespace) scraping `/api/metrics` via a CoreOS `ServiceMonitor` resource.
* **Logs:** Grafana Loki + Promtail (deployed via `loki-stack` Helm chart in `timeguild-monitoring`).
* **Traces:** OpenTelemetry Node SDK (defined in [instrumentation.ts](file:///home/si3mshady/time-guild/src/instrumentation.ts)) ready to export to an OTLP/HTTP target (e.g., collector or Jaeger).

---

## 2. Chronological SRE Actions Log

### 2026-07-14 - Day 7: Observability Autodiscovery & Namespace Scrapes
* **Grafana Stabilization:** Resolved a datasource provisioning conflict (`datasource.yaml` config invalid: only one datasource can be marked as default) in `timeguild-monitoring`. Patched `loki-stack` ConfigMap to set `isDefault: false` and restarted Grafana, bringing Grafana back to healthy `3/3` status.
* **Promtail Namespace Relabeling:** Configured Promtail scraper configuration overrides inside the `loki-stack` Helm release in `timeguild-monitoring`. Added regex relabel rules to match namespaces `tenant-(.*)`, extract the username, and attach a `tenant` label to Loki log streams.
* **Prometheus ServiceMonitor Configuration:** Updated `prometheus-servicemonitor.yaml` to search for services across all namespaces (`namespaceSelector: any: true`) matching the label `app.kubernetes.io/name: timeguild`. Applied the ServiceMonitor to the monitoring namespace.
* **Next.js Dynamic Service Labels:** Updated the dynamic Kubernetes service builder in **[k8s.ts](file:///home/si3mshady/time-guild/src/lib/k8s.ts)** to label dynamically provisioned tenant services with `"app.kubernetes.io/name": "timeguild"` and name the port `"http"`. This enables dynamic Prometheus scraping of dynamic tenant namespaces.
* **W3C Trace Context Middleware:** Implemented a Next.js middleware in **[middleware.ts](file:///home/si3mshady/time-guild/src/middleware.ts)** that extracts/injects `traceparent` headers, sets `Server-Timing` headers, exposes headers to CORS, and logs requests in structured JSON format (filtering out static assets and prometheus metrics scrapes).
* **React Fetch Interceptor:** Modified **[providers.tsx](file:///home/si3mshady/time-guild/src/components/providers.tsx)** to inject W3C standard traceparent context headers (`traceparent = 00-traceId-spanId-flags`) for internal requests, implementing 10% client-side trace sampling.
* **OTel Exporter Protection:** Configured conditional trace exporter inside **[instrumentation.ts](file:///home/si3mshady/time-guild/src/instrumentation.ts)** to only instantiate `OTLPTraceExporter` when `OTEL_EXPORTER_OTLP_ENDPOINT` is present, avoiding StackTrace log pollution in environments where a collector is not running.
