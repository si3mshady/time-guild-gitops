# SRE Journal & Log - Application Repository

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
* **Stripe Webhook CLI Forwarding with K3s Traefik Ingress:** Solved Stripe SSL handshake failures. Since the cluster uses private/self-signed certs (untrusted by Stripe), Stripe aborts webhook delivery to HTTPS endpoints. We configured the local Stripe CLI forwarder to relay messages to `http://timeguild.xyz/api/stripe/webhook` (HTTP instead of HTTPS). Traefik doesn't force HTTP-to-HTTPS redirect, letting Stripe CLI bypass SSL verification and successfully deliver the JSON payload to the dev pod over port 80.
* **Next.js Behind-Proxy Redirect Domain Host Fix:** Fixed a localhost redirect loop after checkout completion. Inside K3s behind Traefik, standard Next.js `new URL(req.url)` calls return the internal service address (`localhost:80` or `127.0.0.1:3000`). We updated `redirect/route.ts` and `checkout/route.ts` to parse `x-forwarded-proto` and `x-forwarded-host` headers to reconstruct the public domain redirect URL, breaking the loop.
* **Grafana Dashboard Auto-Discovery ConfigMap:** Created and labeled the `timeguild-dashboard` ConfigMap in the `timeguild-monitoring` namespace with the tag `grafana_dashboard="1"`. The Grafana sidecar automatically auto-discovered the ConfigMap, saved the configuration to disk, and successfully loaded the dashboard inside the Grafana UI.
* **Onboarding Cookie Security Fix:** Patched [auth-server.ts](file:///home/si3mshady/time-guild/src/lib/auth-server.ts) to set the session cookie `tw_session` to `secure: false`. In local lab environments running on plain HTTP, browsers were silently rejecting the `secure: true` cookie (production default), keeping users trapped in an unauthenticated signup redirect loop when visiting `/onboarding`.
* **Zero-Initialized Metric Resets:** Updated [route.ts](file:///home/si3mshady/time-guild/src/app/api/metrics/route.ts) to initialize all tenant-subdomains and status combinations with default `0` values. Previously, when the database was nuked, metrics lines were omitted from the payload, causing Prometheus to show stale historical counts in Grafana. Initializing metrics with `0` forces Prometheus to scrape the reset and updates dashboards instantly.
* **Kubernetes Tenant Namespace Clean up Automation:** Integrated automatic Kubernetes namespace clean up directly into the database reset endpoint ([route.ts (reset)](file:///home/si3mshady/time-guild/src/app/api/admin/reset/route.ts)). When a "Nuke DB" reset is triggered, the server calls the Kubernetes API using its in-cluster ServiceAccount to delete all dynamic namespaces matching the label `type=tenant`. This guarantees that subsequent demo runs provision clean pods running the current container image, avoiding old image cache/staleness issues on creator domains.
* **Next.js Client GET Request Cache-Busting:** Disabled GET request caching on the `/api/auth/user` endpoint by passing `{ cache: "no-store" }` to client-side `fetch` in [auth-provider.tsx](file:///home/si3mshady/time-guild/src/components/auth-provider.tsx) and returning `Cache-Control: no-store, max-age=0, must-revalidate` headers from [route.ts (user session)](file:///home/si3mshady/time-guild/src/app/api/auth/user/route.ts). This resolved the role selection screen update lag, ensuring that changes to the user's role state are immediately rendered on the UI.

### 2026-07-16 - Day 8: Service Level Indicators (SLIs), Service Level Objectives (SLOs), and Prometheus Alerting Rules
* **Exposition Format Metric Alignment:** Renamed the HTTP latency gauge metric from `timeguild_http_request_duration_seconds` to `timeguild_http_request_duration_seconds_p95` to avoid type conflicts with the histogram of the same name.
* **Exposed SLO Metrics:** Added `timeguild_http_requests_total` counter (measuring Stripe webhook counts and Creator profile endpoint hits) and the `timeguild_http_request_duration_seconds` histogram (exposing cumulative duration buckets for `/api/creators` requests) in `src/app/api/metrics/route.ts`.
* **Prometheus Alerting Rules:** Created and applied `prometheus-rules.yaml` containing alert configurations for critical-path Stripe webhook errors (`StripeWebhookHighErrorRate`) and tolerable-path booking API latency warnings (`BookingLatencyHigh`).
* **Alertmanager Routing Setup:** Configured an `AlertmanagerConfig` resource (`alertmanager-config.yaml`) to route `critical` alerts to PagerDuty (`pagerduty-critical`) and `warning` alerts to Slack (`slack-warnings`) with grouped namespaces.
* **Grafana Dashboard Refinement:** Updated and re-applied the `timeguild-dashboard` ConfigMap (`timeguild-dashboard.yaml`) to use the new `timeguild_http_request_duration_seconds_p95` metric for visualizing response latencies.
* **SRE Runbooks Deployment:** Authored step-by-step troubleshooting runbooks for webhook failures and API latencies under `docs/runbooks/`.

### 2026-07-16 - Day 9: Onboarding, Scheduling & Pricing Engine
* **Flexible Pricing Integration**: Added `pricing_type`, `session_name`, `session_description`, and `zip_code` fields to `creator_profiles` and migrated existing databases dynamically on load using custom SQLite `ALTER TABLE` procedures.
* **Proximity Zip-Code Mapping**: Integrated offline coordinate resolution inside `src/lib/location.ts` mapping 5-digit ZIP codes to approximate coordinates, bypassing browser location API permission blocks.
* **Batch Scheduling Slot Generator**: Developed `src/lib/slots.ts` slot generator that processes date ranges, active weekdays, and hours into available database slots.
* **Onboarding UI Redesign**: Fully refactored `src/app/onboarding/page.tsx` to support flat/hourly billing toggles, session information fields, ZIP-code forms, and active weekday checkboxes for batch scheduler seeding.
* **Dynamic Tag Growth & Boundaries Removal**: Cleaned up the personal boundaries matrix across the onboarding and creator profile interfaces to reflect a professional coaching platform. Implemented a dynamic tag selection API (`/api/tags`) combined with a text entry input to allow interest tags to grow automatically as new profiles publish. Added a DeepSeek AI tag generator endpoint (`/api/tags/generate`) to automatically extract professional activity tags from creator bios with keyword heuristic fallback.

---

## 3. Demo Walkthrough & Recovery Playbook

To spin up the Time Guild application and SRE observability stack for a live demo or recovery walkthrough, follow these steps in order:

### A. Prerequisites & Retrieving Secrets
1. **Retrieve Grafana Admin Credentials**:
   Extract the base64-encoded username and password from the Kubernetes Secret:
   ```bash
   # Decode admin username (should return: admin)
   kubectl get secret -n timeguild-monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-user}" | base64 --decode ; echo

   # Decode admin password (should return: bnfQ7FgNgeOgdjHHe4kICimyHLpMfbM80Ox9PzG1)
   kubectl get secret -n timeguild-monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
   ```

### B. Spinning Up the Stack & Networking
2. **Access the Dashboards**:
   Port-forward the Grafana service from the cluster to your local machine:
   ```bash
   kubectl port-forward svc/prometheus-stack-grafana -n timeguild-monitoring 3000:80
   ```
   Open Grafana at `http://localhost:3000` and sign in using the retrieved credentials.

3. **Tunnel Stripe Webhooks**:
   Because the development cluster uses private/self-signed SSL certificates (untrusted by Stripe), Stripe will fail HTTPS webhook handshakes. Solve this by routing webhooks through the Stripe CLI tunnel:
   ```bash
   stripe listen --forward-to http://timeguild.xyz/api/stripe/webhook
   ```
   *Note: Traefik is configured on port 80 to accept plain HTTP traffic, letting Stripe CLI bypass SSL checks and deliver webhooks directly to dev pods.*

### C. Live Demo Walkthrough (Create, Book, Pay, Verify)
4. **Prepare a Clean State (Nuke DB)**:
   * Click the **"Nuke DB"** button on the floating demo widget in the UI (or hit `POST /api/admin/reset`). This clears previous testing accounts while preserving seeded creators and default configurations.

5. **Generate Activity (Manual or Simulated)**:
   * **Option A: Automated Activity Simulator (Creates 18 users & slots)**:
     ```bash
     ./infra/scripts/test-observability.sh http://timeguild.xyz
     ```
   * **Option B: Manual Customer Flow**:
     - **Create Profile**: Sign up as a new client at `http://timeguild.xyz`.
     - **AI Booking Concierge**: Visit a creator profile (e.g. Avery Chen). Message their AI booking assistant. Answer qualification questions. Once pre-qualified, the assistant renders the "Pay and Book" button.
     - **Stripe Checkout**: Click checkout, complete payment using test card details (`4242...`), and return to the success page.

### D. Multi-Tenant Single Pane of Glass
6. **Verify Observability (Grafana Loki & Prometheus)**:
   - Navigate to Grafana (`http://localhost:3000`) -> SRE Monitoring Dashboard.
   - Use the **`tenant`** dropdown in the top-left to filter metrics and logs.
   - Selecting a tenant (e.g., `avery` or `jen` or `testcreator`) will immediately populate:
     * **Real-time Container Logs (Loki)**: Logs filtered by the selected tenant's namespace with correlated `traceId` context.
     * **System Latencies**: Per-tenant average SQL queries and HTTP request duration graphs.
     * **Consulting Slot Availability**: Donut chart showing booked vs available slots for that creator.
     * **Completed Stripe Transfers**: counters displaying successful payout transfers.
