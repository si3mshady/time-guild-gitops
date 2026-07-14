# SRE Case Study: Observability Autodiscovery in Dynamic SaaS Clusters
**Author:** Principal SRE
**Context:** Time Guild (TimeWorth) Marketplace

---

## 1. LinkedIn Post Proposal

```text
🚀 How do you monitor a multi-tenant SaaS application that dynamically spins up isolated Kubernetes namespaces for users in real-time?

Most DevOps engineers write static configuration files. But when customer namespaces (e.g. `tenant-avery`, `tenant-marcus`) are created and destroyed automatically, static scrapers fail. 

We had to design an autodiscovery pipeline using Kubernetes Service Discovery:

1️⃣ W3C Trace Context Propagation: Stitched client-side user clicks directly to Next.js route handlers. Outgoing requests carry the `traceparent` header (W3C standard), propagating trace state through middleware.
2️⃣ Server-Timing CORS Safeguard: Injected downstream trace timings directly back into browser headers, allowing frontend profiling tools to link API latency to specific backend spans.
3️⃣ Loki Index Protection: Enforced the "Label Split Rule" in Promtail. We extracted tenant names dynamically from namespaces (`tenant-(.*)`) to log streams but kept high-cardinality keys (like user_id or transaction_id) in the JSON body to avoid Out-Of-Memory storage crashes.
4️⃣ Prometheus ServiceMonitors: Configured a single ServiceMonitor across all namespaces (`namespaceSelector: any: true`) matching `app.kubernetes.io/name: timeguild` to dynamically scrape `/api/metrics` the instant a tenant pod registers.

Macro SRE is about system-wide scalability and security boundaries. Micro SRE is about trace propagation details and index preservation rules. When they match, your SaaS is truly production-ready.

#devops #sre #kubernetes #prometheus #grafana #opentelemetry
```

---

## 2. Macro vs. Micro Engineering Analysis

### Macro Rationale (The System-Wide Architecture)
* **Compute Isolation Security:** Running a multi-tenant platform inside a single namespace is a shared-fate security hazard. We isolate each creator inside a dedicated Namespace. If one pod is compromised or OOMs, the blast radius is strictly contained.
* **Service Discovery Scraping:** Prometheus Operator `ServiceMonitor` resources decoupled from the application lifecycle are critical. The Prometheus server doesn't care when or how pods are spun up; K8s API events notify the controller to reconcile targets, achieving sub-second metrics gathering.
* **Low-Cardinality Logging Index:** Shipments to Loki must prevent label cardinality explosions. Traditional index systems crash when storing unique request IDs as labels. Enforcing standard label splits keeps Loki fast, lightweight, and resilient.

### Micro Rationale (The Code-Level Details)
* **W3C Traceparent Header:** Passing trace context via standard format `00-traceId-spanId-flags` ensures cross-vendor compatibility (Jaeger, OTel, Datadog). 
* **CORS Header Exposure:** Browser security restricts access to custom response headers by default. Explicitly exposing `Server-Timing` allows Javascript tracing SDKs inside the client's browser to parse downstream execution times.
* **Port-Name Alignment:** Prometheus ServiceDiscovery matches targets by named ports. The dynamic Next.js service creation in the K8s API must name the target port `"http"` to link with the ServiceMonitor endpoint.
