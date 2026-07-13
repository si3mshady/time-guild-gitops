# Technical Playbook: Lovable-to-Next.js Multi-Tenant Marketplace & GitOps Workflow Guide
This document serves as an exhaustive, staff-level architectural blueprint and step-by-step workflow guide. It bridges **macro-level system design** (topology, promotion pipelines, DNS/SSL routing) with **micro-level execution details** (Next.js server-component boundaries, Stripe Connect escrow states, in-cluster Kubernetes orchestration, and OpenTelemetry monitoring).

---

## 1. Macro Architecture & System Topology

To build, deploy, and scale a multi-tenant marketplace, the system must separate the **Application Code** from the **Infrastructure State (GitOps)**. This separation establishes security boundaries, ensures auditability, and prevents circular CI/CD build loops.

### A. Repository Separation Topology
```
[ Developer Workspace ]                 [ GitOps Workspace ]
  (time-guild repo)                       (time-guild-gitops repo)
         │                                       │
         ├─► Git Push (App Code)                 ├─► ArgoCD Pulls Manifests
         │                                       │
         ▼                                       ▼
  GitHub Actions Runner                   K3s Cluster (ArgoCD Agent)
         │                                       │
         ├─► Builds Docker Image                 ├─► Compares Live Cluster State
         ├─► Pushes to Docker Registry           │   with Git Repository Manifests
         ├─► Updates Image Tag in GitOps         │
         ▼                                       ▼
    Docker Hub                              Reconciles State & Deploys Pods
```

* **The Application Repository (`time-guild`)**: 
  Contains Next.js code, dynamic tenant orchestration logic, local Helm blueprints, scripts, and tests. It does not store environment-specific states or secrets.
* **The GitOps Repository (`time-guild-gitops`)**: 
  Acts as the single source of truth for the cluster's desired state. It contains ArgoCD `ApplicationSets` and environment-specific Helm value overrides (`values-dev.yaml`, `values-lab.yaml`, `values-prod.yaml`).

### B. The Code Promotion & GitOps Lifecycle
1. **Developer Commits**: Code is pushed to the `main` branch of `time-guild`.
2. **CI Pipeline Execution**: GitHub Actions triggers `.github/workflows/docker-publish.yml`.
   * Builds a Docker image using Bun.
   * Compiles native C++ dependencies (e.g. `better-sqlite3`).
   * Tags the image with the short Git SHA: `si3mshady/time-guild:sha-b6cb04c`.
   * Pushes the image to Docker Hub.
3. **Automated Promotion**: GitHub Actions checks out the `time-guild-gitops` repository, updates the image tag in `infra/helm/timeguild/values.yaml` using `sed`, commits, and pushes to remote `main`.
4. **GitOps Sync**: ArgoCD detects the change in git, compares it with the live K3s cluster, and executes a rolling update (`RollingUpdate` strategy) to replace existing containers without downtime.

### C. DNS, SSL, and Ingress Routing Flow
When a user accesses a tenant subdomain (e.g., `elliot.timeguild.local` or `MarcusAurelius.prod.timeguild.xyz`):

```
                             [ DNS Resolution (Namecheap) ]
                                          │
                                          ▼
                                     [ Elastic IP ]
                                          │
                                          ▼
                           [ Traefik Ingress Controller ]
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
     Matches exact Host rule?                        Fallback to Wildcard rule?
  Host("elliott.timeguild.xyz")                      HostRegexp("*.timeguild.xyz")
  (Priority: 10000)                                  (Priority: Default)
                  │                                               │
                  ▼                                               ▼
         [ Service: Port 80 ]                           [ Service: Port 80 ]
                  │                                               │
                  ▼                                               ▼
   [ tenant-elliott Namespace ]                    [ timeguild-dev Namespace ]
   [ Pod: Next.js (PORT=80) ]                      [ Pod: Next.js (PORT=80) ]
                  │                                               │
                  ▼                                               ▼
     Redirects to Creator Profile                     Displays Marketplace Page
```

1. **DNS Lookup**: Namecheap matches the wildcard `*` A record and points the client to the AWS Elastic IP (pointing to the Traefik Ingress controller in the K3s cluster).
2. **Ingress Priority Resolution**: 
   * The default dev environment has a wildcard Ingress: `*.timeguild.local`.
   * The dynamically created tenant ingress has an exact match: `elliot.timeguild.local`.
   * Because Traefik matches by longest rule match first, wildcard routes can conflict. We resolve this by applying a high priority annotation to the dynamically generated tenant ingress spec:
     ```yaml
     traefik.ingress.kubernetes.io/router.priority: "10000"
     ```
     This forces Traefik to evaluate exact host matches before falling back to the wildcard route.
3. **cert-manager Wildcard SSL Integration**:
   * cert-manager uses DNS-01 challenges to verify domain ownership via your DNS provider API.
   * Upon validation, a wildcard SSL certificate is saved as `wildcard-tls-secret` inside the `kube-system` namespace.
   * In Kubernetes, namespaces cannot mount secrets from other namespaces. We bypass this constraint by declaring a `TLSStore` resource in Traefik. This registers the secret as the global default fallback TLS certificate across all namespaces:
     ```yaml
     apiVersion: traefik.containo.us/v1alpha1
     kind: TLSStore
     metadata:
       name: default
       namespace: kube-system
     spec:
       defaultCertificate:
         secretName: wildcard-tls-secret
     ```

---

## 2. Lovable to Next.js Full-Stack Migration

### A. Refactoring React Client State to Server Components
Vite-based Lovable applications rely heavily on client-side routing (React Router) and in-memory mock states. In Next.js, we transition to Server Components by default to optimize loading performance and secure database interactions.

```
                   [ Next.js App Router Page (Server) ]
                     ├── Fetches DB data directly
                     └── Passes initial state to:
                           └── [ Interactive UI Components (Client) ]
                                 └── Tagged with "use client"
                                 └── Handles user clicks and input
```

1. **Routing Migration**: Replace React Router configurations with directory-based routing (`src/app/page.tsx`, `src/app/creator/[id]/page.tsx`).
2. **Component Boundaries**: Keep database access on the server. If a component requires direct user interaction (such as the Chat UI or Booking Calendar), mark it with the `"use client"` directive at the top of the file, and pass the data fetched by the parent Server Component as React props.

### B. Database & Persistence Layer
In a containerized multi-replica deployment, SQLite presents major concurrency risks:
* **The Risk**: If Next.js runs multiple replica pods, they cannot share a single SQLite `.db` file over a standard `ReadWriteOnce` PVC without encountering database locks or file corruption.
* **The Solution (PostgreSQL Migration)**: For production scale, refactor your database client to use connection pooling to PostgreSQL. Define a multi-tenant schema where data is scoped by a `tenant_id` column.
* **Local SQLite PVC Mount Workaround**: If you must use SQLite in a lab environment:
  * **Never** mount the raw database file directly using `subPath` in your PVC spec. If the volume is empty, Kubernetes will create a directory named `time_worth.db` on the host, causing the application to crash.
  * **Instead**, mount a directory path (e.g., `/app/data`) to the Persistent Volume and configure your application environment variable to write inside it:
    ```yaml
    DB_PATH: "/app/data/time_worth.db"
    ```
    This allows SQLite to create and lock the database file dynamically.

### C. Session & Middleware Architecture
Next.js secures APIs and page routes through a global middleware file (`src/middleware.ts`) that intercepts incoming requests before they reach route handlers.

```
Browser Request ──► [ Next.js Middleware ] ──► Validates Cookie Token
                          │
                          ├── Session Valid   ──► Continue to Route
                          └── Session Invalid ──► Redirect to Sign-In
```

1. **Sign-In Flow**: Upon verification of credentials, sign a JWT containing the user's ID, and set it as an HTTP-only, secure cookie:
   ```typescript
   const response = NextResponse.json({ success: true });
   response.cookies.set("tw_session", token, {
     httpOnly: true,
     secure: process.env.NODE_ENV === "production",
     sameSite: "strict",
     maxAge: 60 * 60 * 24, // 24 hours
   });
   ```
2. **Session Verification**: In your middleware or route helpers, verify the cryptographic signature of the cookie before resolving queries.

---

## 3. Stripe Connect & Trust Rules Engine

Marketplaces must securely split payments between consumers (clients), platform commission fees, and provider payouts.

### A. Stripe Connect V2 capabilities
Connected Express Accounts must request specific capabilities to receive transfers. V2 Express integration shifts payment liabilities away from the platform by assigning responsibilities:

```typescript
const account = await stripe.accounts.create({
  type: "express",
  capabilities: {
    card_payments: { requested: true },
    transfers: { requested: true },
  },
  // Connect V2 Liability Enforcement:
  defaults: {
    responsibilities: {
      fees_collector: "application",
      losses_collector: "application",
    },
  },
});
```

### B. Payments & Escrow Flow
Rather than charging a card and paying out immediately, the platform holds funds in escrow during the booking window.

```
[ Client Card ] ──► [ Stripe Checkout Session ] ──► [ Held on Platform Account ]
                                                           │ (transfer_group)
                                                           ├─► Completed ──► Transfer 85% to Creator
                                                           └─► Refunded  ──► Return 100% to Client
```

1. **Checkout Session Creation**: Link the payment to a tracking group (`transfer_group`):
   ```typescript
   const session = await stripe.checkout.sessions.create({
     payment_method_types: ["card"],
     mode: "payment",
     line_items: [{ price_data: { currency: "usd", ... }, quantity: 1 }],
     payment_intent_data: {
       transfer_group: `booking_${bookingId}`,
     },
     success_url: `${origin}/booking/${bookingId}/success`,
     cancel_url: `${origin}/booking/${bookingId}/cancel`,
   });
   ```
2. **Funds Escrow**: The money is charged and held on the platform account. It is not transferred to the creator's connected account until trust rules are satisfied.

### C. The Trust-Rules State Machine
Our state engine ([trust-rules.ts](file:///home/si3mshady/time-guild/src/lib/trust-rules.ts)) controls the release or return of funds:

```
                  ┌───────────────── [ Escrow Locked ] ─────────────────┐
                  │                                                     │
                  ▼ (>= 24h Cancel)                                     ▼ (< 24h Cancel or PIN Verified)
          [ Refund Client ]                                     [ Execute Payout ]
          - Call stripe.refunds                                 - Apply 15% Platform Commission
          - Release slot back to available                      - Transfer 85% net to Connected Express
```

1. **`cancelBooking(bookingId)`**:
   * If cancelled **>= 24 hours** prior to slot start: Call `stripe.refunds.create({ charge: stripe_charge_id })`. Mark status as `refunded` and release the slot back to `available`.
   * If cancelled **< 24 hours** prior: Mark booking as `completed` and proceed to trigger the creator's payout. The client forfeit's their payment due to late cancellation.
2. **`triggerSessionTransfer(bookingId)`**:
   * Calculate commission: Deduct a 15% platform fee from the total paid price.
   * Calculate payout: 85% net goes to the provider.
   * Execute transfer:
     ```typescript
     await stripe.transfers.create({
       amount: Math.round(payoutAmountInCents),
       currency: "usd",
       destination: creator_stripe_account_id,
       transfer_group: stripe_transfer_group,
     });
     ```
3. **PIN Handshake Verification**:
   * To prevent fraud, the client is issued a secure PIN at checkout.
   * Once the session completes, the creator submits the client's PIN via the UI.
   * The server validates the PIN and triggers the transfer, locking the session state to `paid`.

### D. Asynchronous Decoupling & Security Controls
* **Stripe Idempotency Keys**: Network failures can cause duplicate requests. Always provide a unique idempotency key on transfers:
  ```typescript
  await stripe.transfers.create({ ... }, { idempotencyKey: `transfer_booking_${bookingId}` });
  ```
* **Strict HMAC Webhook Validation**: Reject any spoofing attempts by verifying the signature header of incoming Stripe events:
  ```typescript
  const signature = req.headers.get("stripe-signature");
  const event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  ```
* **Asynchronous Queue (BullMQ)**: Payout executions should be queued in Redis using BullMQ. A separate worker process processes the queue, handles automatic retries on rate limits, and updates the database state upon success.

---

## 4. Containerization & In-Cluster K8s Orchestration

### A. Dockerizing Node/Bun standalones
Next.js uses a multi-stage Docker build to keep the production image size small. We compile native modules in the build stage and copy only the built files to the runner stage.

```dockerfile
# Stage 1: Install dependencies and compile better-sqlite3
FROM oven/bun:1.3.14-alpine AS deps
WORKDIR /app
RUN apk add --no-cache python3 make g++ nodejs npm
COPY package.json bun.lock* ./
RUN bun install --ignore-scripts --frozen-lockfile
RUN npm rebuild better-sqlite3

# Stage 2: Build the application standalone
FROM oven/bun:1.3.14-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NODE_ENV=production
RUN bun run build

# Stage 3: Runner stage running under non-root
FROM oven/bun:1.3.14-alpine AS runner
RUN addgroup -g 1001 -S timeguild && adduser -u 1001 -S timeguild -G timeguild
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
USER timeguild
EXPOSE 3000
CMD ["bun", "run", "start"]
```

### B. Application-Controlled Dynamic Provisioning
Our Next.js application acts as a Kubernetes orchestrator using the official client libraries (or direct HTTPS requests to the API server) from within the cluster.

```
[ Next.js Pod ] ──► POST /api/v1/namespaces (Create tenant namespace)
                ──► POST /apis/apps/v1/namespaces/tenant-name/deployments (Deploy App)
                ──► POST /api/v1/namespaces/tenant-name/services (Deploy Service)
                ──► POST /apis/networking.k8s.io/v1/namespaces/tenant-name/ingresses (Route subdomains)
```

1. **Authentication**: The in-cluster Next.js process automatically mounts the service account token: `/var/run/secrets/kubernetes.io/serviceaccount/token`.
2. **Namespace Provisioning**: Create a namespace matching the tenant's username:
   ```json
   {
     "apiVersion": "v1",
     "kind": "Namespace",
     "metadata": { "name": "tenant-elliot", "labels": { "type": "tenant" } }
   }
   ```
3. **Deployment Creation**: Roll out a pod running the same image as the parent application, passing the `TENANT_ID` environment variable to scope database interactions:
   ```json
   {
     "apiVersion": "apps/v1",
     "kind": "Deployment",
     "metadata": { "name": "timeguild-app", "namespace": "tenant-elliot" },
     "spec": {
       "replicas": 1,
       "template": {
         "spec": {
           "containers": [{ "name": "nextjs", "image": "si3mshady/time-guild:sha-b6cb04c", "env": [{ "name": "TENANT_ID", "value": "elliot" }] }]
         }
       }
     }
   }
   ```
4. **Service & Ingress Setup**: Expose the pod over a ClusterIP service, and generate a Traefik Ingress mapping the tenant's host subdomain:
   ```json
   {
     "apiVersion": "networking.k8s.io/v1",
     "kind": "Ingress",
     "metadata": {
       "name": "timeguild-ingress",
       "namespace": "tenant-elliot",
       "annotations": {
         "kubernetes.io/ingress.class": "traefik",
         "traefik.ingress.kubernetes.io/router.priority": "10000"
       }
     },
     "spec": {
       "rules": [{ "host": "elliot.timeguild.local", "http": { "paths": [{ "path": "/", "pathType": "Prefix", "backend": { "service": { "name": "timeguild-service", "port": { "number": 80 } } } }] } }]
     }
   }
   ```

---

## 5. Dual-Repository GitOps Architecture

To prevent configuration drift, manage all environment overrides and ArgoCD templates inside the GitOps repository.

### A. ArgoCD ApplicationSets
In [applicationset.yaml](file:///home/si3mshady/time-guild-gitops/infra/applicationsets/applicationset.yaml), we define a list generator that configures environment values dynamically:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: timeguild-environments
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            valuesFile: values-dev.yaml
          - env: prod
            valuesFile: values-prod.yaml
  template:
    metadata:
      name: 'timeguild-{{env}}'
    spec:
      project: default
      source:
        repoURL: 'https://github.com/si3mshady/time-guild-gitops.git'
        targetRevision: HEAD
        path: infra/helm/timeguild
        helm:
          valueFiles:
            - values.yaml
            - '{{valuesFile}}'
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: 'timeguild-{{env}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

### B. Reusable Helm Blueprints
Your Helm templates inside [infra/helm/timeguild](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild) must follow best practices:
1. **Container Port Matching**: Next.js listens on the port injected by the `PORT` environment variable (resolving to `80`). Ensure your liveness and readiness probe specs query the matching port:
   ```yaml
   ports:
     - name: http
       containerPort: {{ .Values.service.port }}
   ```
2. **Stateful Volume Scoping**: Scope Persistent Volume Claims correctly under Helm values. Use local storage classes or host paths for developer sandboxes, and cloud block storage for production overrides.

---

## 6. Observability & Telemetry

### A. OpenTelemetry Initialization
In [src/instrumentation.ts](file:///home/si3mshady/time-guild/src/instrumentation.ts), bootstrap the OTel Node SDK on next.js runtime startup to automatically trace all incoming HTTP calls, database requests, and outbound APIs:

```typescript
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";

if (process.env.NEXT_RUNTIME === "nodejs") {
  const sdk = new NodeSDK({
    traceExporter: new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || "http://jaeger:4318/v1/traces",
    }),
    instrumentations: [
      getNodeAutoInstrumentations({
        "@opentelemetry/instrumentation-fs": { enabled: false }, // Disable noisy filesystem traces
      }),
    ],
  });
  sdk.start();
}
```

### B. Custom Prometheus Exposition API
Expose system performance and business metrics directly through Next.js at `/api/metrics` ([route.ts](file:///home/si3mshady/time-guild/src/app/api/metrics/route.ts)):

```typescript
import { NextResponse } from "next/server";
import db from "@/lib/db";

export async function GET() {
  const metrics: string[] = [];
  
  // 1. Collect database business metrics
  const bookings = db.prepare("SELECT status, COUNT(*) as count FROM bookings GROUP BY status").all() as any[];
  metrics.push("# HELP timeguild_bookings_total Total bookings by status");
  metrics.push("# TYPE timeguild_bookings_total counter");
  for (const b of bookings) {
    metrics.push(`timeguild_bookings_total{status="${b.status}"} ${b.count}`);
  }

  // 2. Format SRE Golden Signals (mocked or extracted from OTel metrics API)
  metrics.push("# HELP timeguild_http_request_duration_seconds P95 latency gauge");
  metrics.push(`timeguild_http_request_duration_seconds{quantile="0.95"} 0.145`);

  return new Response(metrics.join("\n") + "\n", {
    headers: { "Content-Type": "text/plain; version=0.0.4; charset=utf-8" },
  });
}
```

Prometheus scrapes this endpoint every 15s using a CoreOS operator `ServiceMonitor` ([prometheus-servicemonitor.yaml](file:///home/si3mshady/time-guild-gitops/infra/monitoring/prometheus-servicemonitor.yaml)):

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: timeguild-monitor
  namespace: timeguild-prod
spec:
  selector:
    matchLabels:
      app: timeguild
  endpoints:
    - port: http
      path: /api/metrics
      interval: 15s
```

### C. Promtail & Loki Logging Pipeline
Loki runs as a single-binary store, and Promtail runs as a DaemonSet to parse logs from `/var/log/pods`.

```
[ App stdout/stderr ] ──► [ Promtail DaemonSet ] ──► [ Grafana Loki ] ──► [ Grafana Explore Dashboard ]
```

Promtail uses relabeling rules to structure unstructured logs before sending them to Loki:
* Extracts the container engine format.
* Filters namespaces matching `timeguild-*` or `tenant-*`.
* Tags logs with metadata: `namespace`, `pod`, and `container`.
* Loki stores these logs indexed by metadata, enabling LogQL queries inside Grafana:
  ```logql
  {namespace="tenant-elliot", container="nextjs"}
  ```
This provides SRE-level observability without resource exhaustion in home lab environments.
