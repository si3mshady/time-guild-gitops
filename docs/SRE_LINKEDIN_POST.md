# SRE Case Study: Observability Autodiscovery in Dynamic SaaS Clusters
**Author:** Principal SRE
**Context:** Time Guild (TimeWorth) Marketplace

---

## 1. LinkedIn Post Proposal (Observability Autodiscovery)

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

## 2. LinkedIn Post Proposal (Stripe Webhook SSL & Proxy Host Redirect Focus)

```text
🚀 Diagnosing the "Silent Loop": Solving Stripe Webhook SSL Handshakes & Next.js Proxy Redirects in Kubernetes

Ever deployed an app behind a proxy/ingress in K8s, completed a payment checkout, and got stuck in an infinite "Awaiting Payment" loop? 

We spent today debugging this exact scenario in a multi-tenant SaaS application, and the root cause came down to two classic network challenges:

1️⃣ The SSL Verification Wall: Stripe webhooks require HTTPS for public domains and strictly verify SSL certificates. Since our development cluster runs private/self-signed certs, Stripe's servers failed the TLS handshake and aborted webhook delivery. No webhooks = booking status stuck in 'awaiting_payment' = loop.
   👉 Solution: Tunnel securely. We ran a local Stripe CLI forwarder mapping webhooks to our plain HTTP endpoint (http://timeguild.xyz/api/stripe/webhook). Since Traefik accepts plain HTTP traffic on port 80, the CLI bypassed SSL checks and successfully delivered payloads to our dev pod.

2️⃣ The Localhost Redirect Trap: Inside K8s behind Traefik, standard Next.js 'new URL(req.url)' queries resolved to the internal container address (localhost:80), redirecting users to localhost after checkout completed!
   👉 Solution: Respect headers. We refactored the checkout session and redirect APIs to reconstruct the public origin using proxy-propagated headers: 'x-forwarded-proto' (https) and 'x-forwarded-host' (timeguild.xyz).

3️⃣ Auto-Discovery Dashboards: We packaged our custom Grafana dashboard JSON into a Kubernetes ConfigMap, tagged with 'grafana_dashboard: "1"'. The Grafana sidecar automatically auto-discovered the map, injected it into disk, and populated the UI in real-time.

Telemetry isn't just about pretty graphs—it's the only way to detect why a webhook was silently swallowed or why a redirect URL went rogue. 

#devops #sre #kubernetes #grafana #stripe #webdevelopment #softwareengineering
```

---

## 3. Macro vs. Micro Engineering Analysis

### Macro Rationale (The System-Wide Architecture)
* **Compute Isolation Security:** Running a multi-tenant platform inside a single namespace is a shared-fate security hazard. We isolate each creator inside a dedicated Namespace. If one pod is compromised or OOMs, the blast radius is strictly contained.
* **Service Discovery Scraping:** Prometheus Operator `ServiceMonitor` resources decoupled from the application lifecycle are critical. The Prometheus server doesn't care when or how pods are spun up; K8s API events notify the controller to reconcile targets, achieving sub-second metrics gathering.
* **Low-Cardinality Logging Index:** Shipments to Loki must prevent label cardinality explosions. Traditional index systems crash when storing unique request IDs as labels. Enforcing standard label splits keeps Loki fast, lightweight, and resilient.

### Micro Rationale (The Code-Level Details)
* **W3C Traceparent Header:** Passing trace context via standard format `00-traceId-spanId-flags` ensures cross-vendor compatibility (Jaeger, OTel, Datadog). 
* **CORS Header Exposure:** Browser security restricts access to custom response headers by default. Explicitly exposing `Server-Timing` allows Javascript tracing SDKs inside the client's browser to parse downstream execution times.
* **Port-Name Alignment:** Prometheus ServiceDiscovery matches targets by named ports. The dynamic Next.js service creation in the K8s API must name the target port `"http"` to link with the ServiceMonitor endpoint.
