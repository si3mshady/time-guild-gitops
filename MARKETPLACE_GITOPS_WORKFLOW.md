# Blueprint: Lovable-to-Next.js Marketplace & GitOps Workflow Guide
This document serves as an engineering blueprint for future projects. It outlines the end-to-end workflow to take a **Lovable** design export, convert it into a full-stack **Next.js** application, integrate a secure **Stripe Connect marketplace**, containerize it with **Bun**, orchestrate dynamic multi-tenancy, and deploy it via a dual-repository **GitOps** pipeline.

---

## Phase 1: Lovable Export to Next.js Migration

Lovable excels at rapid UI prototyping and front-end generation. However, turning it into a production-grade, state-managed SaaS product requires migrating to Next.js App Router.

### Step 1: Code Export & Asset Preservation
1. Download the complete ZIP export from the Lovable editor.
2. Extract the React code (typically a Vite-based app) and copy the UI layouts, design assets, and styles.
3. Document the initial mock schema used in Lovable's state handlers to design your SQL schema.

### Step 2: Bootstrap Next.js (App Router)
1. Initialize a clean Next.js project using Tailwind CSS and TypeScript:
   ```bash
   npx create-next-app@latest ./ --typescript --tailwind --app --src-dir
   ```
2. Configure styling frameworks (e.g., shadcn/ui) in `components.json` and ensure your `postcss.config` is aligned.
3. Migrate custom styles into `src/app/globals.css`.

### Step 3: Database & State Layer Refactoring
1. **Choose Your Driver**: For development portability, use SQLite via `better-sqlite3` or `bun:sqlite` (see [db.ts](file:///home/si3mshady/time-guild/src/lib/db.ts)). For production scale, configure connection pooling (e.g. `pg` or `postgres` with PgBouncer).
2. **Schema Definition**: Define standard tables for:
   * Tenants (`tenants` table with unique subdomains).
   * Users & Roles (client vs. creator).
   * Marketplace inventory (slots, bookings).
   * Auditing (chat logs, transactions).
3. **Migrate mock state handlers**: Locate the client-side state (e.g., `useState` mocks for bookings or slots) and replace them with server-side database executions inside Next.js API Routes (`src/app/api/...`) or Server Actions.

### Step 4: Auth & Session Management
1. Standardize on cookie-based session management (`tw_session`) or a provider like Supabase Auth.
2. In-house JWT cookie pattern:
   * Write session tokens upon sign-in.
   * Parse cookies in a server utility ([auth-server.ts](file:///home/si3mshady/time-guild/src/lib/auth-server.ts)).
   * Secure APIs using a Next.js `middleware.ts` file to intercept unauthorized requests.

---

## Phase 2: Stripe Connect & Escrow Architecture

Marketplaces must segregate funds legally (avoiding credit card processing liabilities) and manage payouts.

### Step 1: Stripe Connect Capabilities
1. Create a platform account in the Stripe Dashboard.
2. When onboarding creators, create **Express Connected Accounts** using the Stripe SDK:
   ```typescript
   const account = await stripe.accounts.create({
     type: 'express',
     capabilities: {
       card_payments: { requested: true },
       transfers: { requested: true },
     },
     // V2 Express/Connect defaults to shift liability to platform:
     defaults: {
       responsibilities: {
         fees_collector: 'application',
         losses_collector: 'application',
       }
     }
   });
   ```

### Step 2: Stripe Checkout Sessions
1. Create a Stripe Checkout Session on the platform account for bookings.
2. Pass a `transfer_group` (e.g., `booking_${bookingId}`) to group the client's charge with the subsequent payout transfer.
3. **Do not** use experimental API headers like `allocated_funds` unless your platform account is explicitly whitelisted by Stripe. Use standard Connect rules instead.

### Step 3: Trust Rules & Escrow Release
1. Implement an automated state engine ([trust-rules.ts](file:///home/si3mshady/time-guild/src/lib/trust-rules.ts)) to enforce cancellation/completion policies:
   * **Full Refund**: If cancelled >= 24h prior, call `stripe.refunds.create` and return the slot to `available`.
   * **Non-Refundable**: If cancelled < 24h, transition the booking to `completed` and trigger the payout.
   * **Handshake / PIN Verification**: At session end, require the provider to submit a PIN generated for the client to confirm completion and trigger `stripe.transfers.create` (85% creator, 15% platform commission).
2. **Interview Pitch vs. Reality**: For production reliability, do not run payouts synchronously in HTTP threads. Queue the tasks using a Redis worker (e.g., **BullMQ**) and wrap transfers in Stripe idempotency keys (`stripe.transfers.create(..., { idempotencyKey: ... })`).

### Step 4: Webhook Verification
1. **Always** check Stripe webhook signatures using `stripe.webhooks.constructEvent` with your endpoint secret.
2. Throw an error and block database writes if webhook HMAC validation fails.

---

## Phase 3: Containerization & In-Cluster Orchestration

To run a multi-tenant platform, the application needs to be packaged cleanly and must be able to control its own infrastructure.

### Step 1: Bun-Hardened Dockerfile
1. Use multi-stage builds to optimize image size and build speeds.
2. Avoid running containers as root. Configure a dedicated system group and user in the Dockerfile:
   ```dockerfile
   FROM oven/bun:1.3.14-alpine AS runner
   RUN addgroup -g 1001 -S timeguild && adduser -u 1001 -S timeguild -G timeguild
   USER timeguild
   ```

### Step 2: Dynamic Tenant Provisioning
1. Give your Next.js application pod a ServiceAccount with ClusterRole permissions to manage namespaces, deployments, services, and ingresses.
2. Use the in-cluster token (`/var/run/secrets/...`) to authenticate calls directly to the Kubernetes API server ([k8s.ts](file:///home/si3mshady/time-guild/src/lib/k8s.ts)).
3. When a user registers a tenant:
   * Create a namespace `tenant-${username}`.
   * Roll out a deployment running the parent application image.
   * Create a ClusterIP Service.
   * Create an Ingress with an exact host match annotation and set high priority (e.g. `router.priority: "10000"` for Traefik) to override the default wildcard ingress.

---

## Phase 4: GitOps & Deployment Architecture

Separate your application logic from cluster configuration states to ensure declarative management.

```
[ App Code Repo ] ──────> GitHub Actions (Build/Push) ───┐
                                                         │ (Updates tag)
                                                         ▼
[ GitOps State Repo ] ──> ArgoCD ApplicationSets ──> K8s Cluster
```

### Step 1: Repo Separation
* **Application Repo**: Code, local Helm blueprints, scripts, and tests.
* **GitOps Repo**: Environment overrides (`values-dev.yaml`, `values-prod.yaml`), ArgoCD ApplicationSet controllers, and cluster configuration files.

### Step 2: Robust Helm Chart Design
1. **Resolve Port Mismatch**: Do not hardcode container ports (like 3000) if your Service runs on port 80. Pass the `PORT` env var to Next.js dynamically via ConfigMaps to match the Service port.
2. **SQLite Directory Mounts**: When using SQLite PVCs, do not mount the raw `.db` file using `subPath` (this creates a directory instead of a file on new volumes). Mount the directory (e.g., `/app/data`) and define `DB_PATH: /app/data/time_worth.db`.
3. **Autoscaling & Network Policies**: Include HPAs for horizontal scalability and NetworkPolicies to restrict cross-tenant communication.

### Step 3: ArgoCD ApplicationSets
* Use list generators in `applicationset.yaml` to parse environment settings.
* Set automated pruning and self-healing for non-production environments (`dev`, `staging`), and require manual approvals for production.

### Step 4: Automated CI/CD Promotion
In your App repository GitHub Actions:
1. Build and push the Docker image tagged with the short Git SHA.
2. Clone the GitOps repository.
3. Update `values.yaml` with the new image tag.
4. Commit and push the GitOps updates. (ArgoCD will automatically sync the change).

---

## Phase 5: Observability & Monitoring

Never deploy black-box applications. Integrate telemetry to observe performance.

### Step 1: OpenTelemetry (OTel) Node SDK
1. Initialize the OTel Node SDK inside `instrumentation.ts` to hook into Next.js startup.
2. Use trace exporters (like `OTLPTraceExporter`) to send spans to collectors (Jaeger/OpenTelemetry Collector).
3. Disable noisy instrumentation (like filesystem reads `instrumentation-fs`) to keep traces clean.

### Step 2: Native Prometheus Exposition
1. Build an API route `/api/metrics` to expose metrics.
2. Query your database inside the API route to collect business telemetry (e.g. active users, revenue, transfer counts) and format them into Prometheus exposition syntax.
3. Configure a CoreOS `ServiceMonitor` to scrape the `/api/metrics` path.

### Step 3: Lightweight Logging
* For resource-constrained lab environments, avoid heavy ELK stacks.
* Implement **Grafana Loki** with **Promtail** daemonsets. Promtail reads Docker container logs from stdout/stderr, tags them with Kubernetes labels, and pushes them to Loki for visualization in Grafana.
