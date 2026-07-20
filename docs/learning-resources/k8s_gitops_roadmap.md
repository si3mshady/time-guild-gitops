# GitOps & Kubernetes Implementation Roadmap

This roadmap details the step-by-step transition from a **local Docker Compose** environment to a production-like, containerized, GitOps-managed **Kubernetes (K3s)** cluster, alongside the implementation of all multi-tenant creator scheduling features, Stripe Connect integrations, observability systems, and 2026 AI-era DevOps/Platform engineering primitives.

---

## Maturity Roadmap Overview

We have successfully built a highly resilient, multi-tenant scheduling marketplace. Currently, **Day 1 to Day 12, Day 12-a, and Day 13-a are fully COMPLETED**, **Day 13 is the CURRENT ACTIVE DAY (Outstanding)**, and **Days 14 through 20 are FUTURE PHASES (Outstanding)**.

```text
               [ Day 1 - Day 5: Core Infrastructure Setup ] (Completed)
                                   │
                                   ▼
               [ Day 6 - Day 8: K8s Dynamic REST API & Observability ] (Completed)
                                   │
                                   ▼
               [ Day 9 - Day 12: Business Engine, Payouts, & Slot Budgets ] (Completed)
                                   │
                                   ▼
               [ Day 12-a: Flexible Scheduling, Pricing Templates, & Lifecycle ] (Completed)
                                   │
                                   ▼
               [ Day 13-a: Test Suite Alignment, Telemetry & DB Integrity ] (Completed)
                                   │
                                   ▼
                [ Day 13: Interactive Calendars & Visual Schedule ] (Current Active Day - Outstanding)
                                   │
                                   ▼
                [ Day 14: Observability Verification & End-to-End Testing ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 15: Testing Framework Restoration & E2E Validation ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 16: Nginx Edge Proxy, Rate Limiting, & WAF Security Telemetry ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 17: OpenTelemetry Distributed Tracing & Unified APM ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 18: AI FinOps, Token Cost Tracing & Security Guardrails ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 19: Model Context Protocol (MCP) Integration Infrastructure ] (Future Phase - Outstanding)
                                   │
                                   ▼
                [ Day 20: K8s AI Workload Hardening & Outcome-Based Analytics ] (Future Phase - Outstanding)
```

---

## Day 1 — Foundation & Stripe Connect Integration (COMPLETED)
* **Goal**: Set up unique tenant checks, database lockouts, and Stripe Connect recipient onboarding.
* **Tasks Completed**:
  1. Implemented unique username validation and schema isolation rules.
  2. Integrated Connect Express V2 registration routes.

## Day 2 — Production Containerization & CI/CD (COMPLETED)
* **Goal**: Package the app for cloud delivery using automated pipelines.
* **Tasks Completed**:
  1. Created a multi-stage Bun Alpine Dockerfile.
  2. Setup GitHub Actions (`docker-publish.yml`) to automatically build and push to Docker Hub.

## Day 3 — Cloud Host & DNS Wildcards (COMPLETED)
* **Goal**: Spin up cloud hosts and map wildcard records.
* **Tasks Completed**:
  1. Configured AWS EC2 and associated a static AWS Elastic IP (EIP).
  2. Mapped wildcard Namecheap DNS records (`*.yourdomain.com`).
  3. Exported EC2 K3s kubeconfig for remote `kubectl` administration.

## Day 4 — GitOps Engine & Helm Packaging (COMPLETED)
* **Goal**: Sync deployment states using declarative GitOps models.
* **Tasks Completed**:
  1. Installed ArgoCD on K3s.
  2. Refactored the Helm chart under `infra/helm` and configured an ArgoCD Application manifest.

## Day 5 — cert-manager & Wildcard Ingress HTTPS (COMPLETED)
* **Goal**: Secure dynamic routing paths automatically.
* **Tasks Completed**:
  1. Delegated DNS nameservers to Cloudflare for DNS-01 verification.
  2. Provisioned Let's Encrypt wildcard certificate via `cert-manager`.
  3. Configured Traefik default TLSStore for automatic subdomain HTTPS.

## Day 6 — Dynamic Namespace Provisioner (COMPLETED)
* **Goal**: Allow Next.js to spawn isolated tenant pods dynamically on creator signup.
* **Tasks Completed**:
  1. Bound Next.js service account to K8s Namespace/Ingress/Deployment creation rights.
  2. Authored K8s REST helper client in `src/lib/k8s.ts`.

## Day 7 — Observability Auto-Discovery (COMPLETED)
* **Goal**: Auto-collect logs/metrics when tenant pods spin up.
* **Tasks Completed**:
  1. Configured Promtail Kubernetes service discovery rules.
  2. Implemented dynamic ServiceMonitors matching `tenant-*` namespaces.

## Day 8 — SRE SLIs, SLOs & Alerting Rules (COMPLETED)
* **Goal**: Guard the cluster against latencies and failures.
* **Tasks Completed**:
  1. Deployed Prometheus alerting rules targeting SLOs (95% request latencies under 500ms).
  2. Integrated Alertmanager rules.

## Day 9 — Scheduling, Pricing Engine & Loki Queries (COMPLETED)
* **Goal**: Support custom pricing models and simplify log troubleshooting.
* **Tasks Completed**:
  1. Designed flat vs hourly slots pricing with ZIP code validation.
  2. Simplified Grafana Loki log panels to query logs by namespace.

## Day 10 — Payment Consistency & Testing (COMPLETED)
* **Goal**: Verify funds splits, platform commissions, and refunds.
* **Tasks Completed**:
  1. Written Vitest test coverage suite validating slot availability constraints.
  2. Implemented Stripe webhook triggers for `charge.refunded` handling.

## Day 11 — Rescheduling Workflows (COMPLETED)
* **Goal**: Enable booking modifications, cancellations, and notifications.
* **Tasks Completed**:
  1. Implemented client/creator booking list endpoints.
  2. Configured rescheduling rules (preventing alterations within 24 hours).

## Day 12 — Slot UX Refinement & Weekly Budgets (COMPLETED)
* **Goal**: Enforce weekly availability boundaries and optimize dashboards.
* **Tasks Completed**:
  1. Split dashboard screens into distinct tabs (**Client Bookings**, **Sessions I Booked**, **Availability**, **Stripe Onboarding**).
  2. Grouped availability slots into daily grids.
  3. Enforced timezone-safe weekly availability budgets (max slots).

## Day 12-a — Flexible Scheduling, Pricing Templates, & Lifecycle Refactoring (COMPLETED)
* **Goal**: Separate static session templates from dynamic recurring availability windows and track explicit state transitions.
* **Tasks Completed**:
  1. Authored `availability_windows` SQLite table supporting recurring weekly blocks and date overrides.
  2. Implemented `syncSlotsFromAvailability` engine in `src/lib/availability.ts` to dynamically seed 30-day chronological slots.
  3. Upgraded booking state machine with explicit lifecycle transitions (`draft` → `pending_payment` → `confirmed` → `in_progress` → `completed` → `canceled` / `refunded`).
  4. Emitted structured `[OBSERVABILITY]` logs for all critical booking and payout events.

## Day 13-a — Test Suite Alignment, Telemetry Integration, & Database Migration Integrity (COMPLETED)
* **Goal**: Align metrics endpoints, database pragmas, and CI pipelines with refactored lifecycle states.
* **Tasks Completed**:
  1. Expanded Prometheus `/api/metrics` exporter to aggregate counts and revenue for all new status states.
  2. Wrapped database schema transactions in `PRAGMA foreign_keys = OFF / ON` in `db.ts` to prevent constraint corruption.
  3. Overhauled `/api/admin/reset` nuke route to drop and cleanly rebuild all tables and seed data.
  4. Optimized `.github/workflows/docker-publish.yml` to remove stale Vitest runners until Day 15 restoration.

---

## Day 13 — Calendar UX & Scheduling Enhancements (CURRENT ACTIVE DAY - OUTSTANDING)
* **Goal**: Replace flat form availability lists with calendar-based interfaces.
* **Tasks**:
  1. **Visual Planner Calendar**: Implement a monthly/weekly calendar grid on the creator dashboard showing available, booked, and reserved slot states.
  2. **Visual Planner Schedule details**: Enable hover tooltips with pricing (flat/variable) and client profiles.
  3. **Client-Side Selector**: Refactor the profile page slot dropdown into an interactive date/time calendar picker.

---

## Day 14 — Observability Verification & End-to-End Testing (FUTURE PHASE - OUTSTANDING)
* **Goal**: Audit financial transaction metrics and script end-to-end verification workflows.
* **Tasks**:
  1. **Expose Business Metrics**: Expose commission balances, payout totals, and pricing model popularity via Prometheus gauges.
  2. **Grafana ConfigMap updates**: Update the cluster ConfigMap dashboard.
  3. **E2E Testing Script**: Develop `/infra/scripts/test-e2e-bookings.sh` to automatically simulate onboarding, checkout, webhook callbacks, and payouts.

---

## Day 15 — Testing Framework Restoration & E2E Validation (FUTURE PHASE - OUTSTANDING)
* **Goal**: Re-architect and restore Vitest test suites aligning with the refactored database schemas and flexible booking rules.
* **Tasks**:
  1. **Codebase State Machine Audit**: Document dynamic slot-slicing bounds and state machine transition rules.
  2. **Unit Test Suite Rebuild**: Write unit tests covering pricing, commission calculations, and late cancellation guards.
  3. **Integration Test Suite Rebuild**: Write integration tests covering availability rule synchronization, Stripe Webhooks mock processing, and Stripe Connect split payout rules.

---

## Day 16 — Nginx Edge Proxy, Rate Limiting, & WAF Security Telemetry (FUTURE PHASE - OUTSTANDING)
* **Goal**: Configure an Nginx edge proxy with WAF rules and rate-limiting zones to filter and monitor edge request traffic.
* **Tasks**:
  1. **Nginx Reverse Proxy & TLS Ingress**: Set up Nginx to terminate TLS and forward requests to internal cluster ingresses.
  2. **API Rate Limiting**: Limit high-frequency API probes on sensitive paths like checkout and authentication routes.
  3. **WAF Security & Telemetry Export**: Deploy OWASP Coraza WAF rules on Nginx, parse blocks to JSON, and collect/forward security alerts to Prometheus & Grafana.

---

## Day 17 — OpenTelemetry Distributed Tracing & Unified APM (FUTURE PHASE - OUTSTANDING)
* **Goal**: Trace complete end-to-end user transactions across Next.js API endpoints, Stripe Webhooks, database queries, and async jobs.
* **Tasks**:
  1. **OpenTelemetry Node SDK Setup**: Integrate `@opentelemetry/sdk-node` into Next.js `instrumentation.ts`.
  2. **Journey Span Instrumentation**: Trace end-to-end requests: Creator Onboarding → Availability Setup → Booking Checkout → Stripe Webhooks → Connected Account Payout Transfer.
  3. **Jaeger / Tempo Integration**: Export traces to Jaeger / Grafana Tempo and set up P95 latency alerts on payment flows.

---

## Day 18 — AI FinOps, Token Cost Tracing & Security Guardrails (FUTURE PHASE - OUTSTANDING)
* **Goal**: Track token-level costs, monitor LLM API latency, enforce prompt security guardrails, and auto-summarize incidents.
* **Tasks**:
  1. **Token Cost Attribution Telemetry**: Instrument AI requests with Prometheus metrics (`timeguild_llm_tokens_total`, `timeguild_llm_cost_cents_total`) tagged by tenant, model, and endpoint.
  2. **AI FinOps Grafana Dashboard**: Build visual panels comparing AI operational costs against platform revenue.
  3. **AI Security Guardrails Middleware**: Add prompt injection detection, input validation, and PII filtering for AI agent endpoints.
  4. **AI SRE Incident Summarization Agent**: Deploy an automated agent hook to summarize Loki error logs into incident summaries.

---

## Day 19 — Model Context Protocol (MCP) Integration Infrastructure (FUTURE PHASE - OUTSTANDING)
* **Goal**: Adopt Model Context Protocol (MCP) to allow platform AI agents to securely connect to external tools and data sources.
* **Tasks**:
  1. **MCP Server Integration**: Authored `src/lib/mcp/server.ts` exposing Time Guild primitives (bookings, slots, creator profiles, metrics) as standard MCP tools.
  2. **MCP Client Agent Integration**: Equip internal agents with an MCP client interface to securely pull external context (calendars, GitHub, web data).
  3. **Granular Permissions & Tool Auth**: Implement RBAC and token isolation for external tool invocation.

---

## Day 20 — K8s AI Workload Hardening & Outcome-Based Analytics (FUTURE PHASE - OUTSTANDING)
* **Goal**: Harden Kubernetes for AI/inference workloads and establish outcome-based pricing analytics.
* **Tasks**:
  1. **Pod Resource Limits & PodDisruptionBudgets**: Configure explicit memory/CPU limits and PodDisruptionBudgets across tenant namespaces.
  2. **KEDA / HPA Queue Autoscaling**: Deploy KEDA or HPA rules for autoscaling tenant workloads based on queue depth and request concurrency.
  3. **Outcome-Based Metrics**: Expose Prometheus gauges for booking success rates, agent intervention value, and automated time saved.
