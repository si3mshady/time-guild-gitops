# Day 17: Distributed Tracing & Unified APM

> [!WARNING]
> **Status: OUTSTANDING (Future Phase)**

---

## 1. Architectural Rationale: Why We Do This
As multi-tenant routing, Stripe webhooks, and multi-agent AI interactions scale, diagnosing end-to-end latency bottlenecks or cross-boundary failures requires distributed tracing across every system boundary.
* **Unified Request Visibility**: Correlate single user requests as they pass through Next.js API routes, database queries, Stripe payment webhooks, and connected account transfers.
* **SLO & Error Budget Monitoring**: Measure P95 transaction latencies and pinpoint exact span failures to maintain strict service level objectives.

---

## 2. Core Tasks

### A. OpenTelemetry Node SDK Setup
* Configure `@opentelemetry/sdk-node` and `@opentelemetry/auto-instrumentations-node` in Next.js `instrumentation.ts`.
* Enable trace propagation headers (`traceparent`, `tracestate`) across all internal HTTP calls and API endpoints.

### B. User Journey Span Instrumentation
Instrument custom spans to track key business transactions:
* **Creator Onboarding & Provisioning**: Trace tenant registration → K8s namespace creation → DB initialization.
* **Booking & Payment Journey**: Trace availability lookup → LangGraph agent routing → Stripe Checkout creation → Webhook processing → Express account payout transfer.

### C. Jaeger / Tempo & Grafana APM Integration
* Export traces via OTLP gRPC/HTTP collectors to Jaeger or Grafana Tempo.
* Connect trace data with Loki logs and Prometheus metrics in Grafana for unified APM visualization.
* Configure automated alerts for P95 latency breaches (>500ms) on critical payment endpoints.

---

## 3. Study & Reference Materials
* **OpenTelemetry Next.js Guide**: Integrating OpenTelemetry tracing in Next.js applications:  
  [https://nextjs.org/docs/app/building-your-application/optimizing/open-telemetry](https://nextjs.org/docs/app/building-your-application/optimizing/open-telemetry)
* **Grafana Tempo & Jaeger Tracing**: Best practices for distributed tracing and APM dashboards:  
  [https://grafana.com/docs/tempo/latest/](https://grafana.com/docs/tempo/latest/)
