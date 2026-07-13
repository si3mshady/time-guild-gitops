# Day 1: Unique Username Enforcement, Database Schema Locks, and Stripe Connect Integration

This document logs the design decisions, engineering principles, and implementation details for Day 1 of the GitOps-driven multi-tenant database and security migration.

---

## 1. Engineering Principles

### DNS-Safe Subdomain Validation
To support GitOps-driven automated provisioning of tenant routing (e.g. `username.timeworth.local`), we must enforce username constraints at registration. A valid subdomain must conform to RFC 1123, which specifies:
*   Only lowercase alphanumeric characters and hyphens (`[a-z0-9-]`) are permitted.
*   It must start and end with an alphanumeric character (hyphens cannot be at the start or end).
*   Maximum length is 63 characters.
*   Must not collide with reserved names (e.g. `www`, `api`, `admin`) to prevent subdomain hijacking or traffic hijacking of platform services.

### Stripe Connect Metadata Tagging
When creating Stripe Connected Accounts, passing the `username` in the account metadata links the real Stripe Test/Developer platform account to the corresponding database tenant. This metadata makes it easy to trace payments and reconcile balances in the Stripe Test Dashboard.

### Telemetry Segmentation
In a multi-tenant platform, observability must be tenant-aware. High-cardinality values like tenant IDs are mapped to labels in Prometheus metrics and structured fields in Loki logs. This allows engineers to query system signals (latencies, counts, rates) filtered per tenant.

---

## 2. Changes Executed

### Database Schema Updates
*   **SQLite (`src/lib/db.ts`)**: Added the `username` column to the `users` table, with a fallback migration check. Updated database seeds to assign `"avery"`, `"sarah"`, and `"marcus"` usernames.
*   **Postgres Migration (`supabase/migrations/20260709010000_add_unique_username.sql`)**: Created migration to add a unique `username` column to the `profiles` table.

### API Endpoint Refinement
*   **Signup Route (`src/app/api/auth/signup/route.ts`)**: Enforced validation rules (regex and reserved list check) for incoming usernames. Added `[SIGNUP]` prefix logs for success events.
*   **Signin Route (`src/app/api/auth/signin/route.ts`)**: Added `[LOGIN]` prefix logs for successful sign-in events.
*   **Creators Profile Route (`src/app/api/creators/route.ts`)**: Automatic tenant row creation under the unique username subdomain upon creator onboarding. Added `[TENANT]` and `[CREATOR]` prefix logs.
*   **Stripe Connect Onboarding (`src/app/api/stripe/connect/route.ts`)**: Passed `{ metadata: { username } }` in the `/v2/core/accounts` Stripe endpoint call. Added `[STRIPE]` prefix logs.
*   **Metrics Exposition (`src/app/api/metrics/route.ts`)**: Added tenant-specific dimensions for bookings, slots, and revenue metrics.
*   **Admin Reset Route (`src/app/api/admin/reset/route.ts`)**: Configured seeds to preserve username fields during reset cycles.

### Frontend Enhancements
*   **Auth View (`src/app/auth/page.tsx`)**: Form field for username entry at registration, showing realtime validation.
*   **Auth State Context (`src/hooks/use-auth.ts`, `src/components/auth-provider.tsx`)**: Expanded `AuthUser` types to track username throughout components.

---

## 3. Step-by-Step Testing & Verification Guide

This section describes how to spin up the local Docker environment, run the bulk test generator, and review observability data.

### A. Docker Compose Commands & Ports Reference
Run all commands from the project root (`/home/si3mshady/time-guild`).

1.  **Start all services** (Next.js app, Postgres, Redis, Prometheus, Grafana, Loki, Promtail, Jaeger):
    ```bash
    docker compose -f infra/compose/docker-compose.yaml up -d --build
    ```
2.  **Verify service status**:
    ```bash
    docker compose -f infra/compose/docker-compose.yaml ps
    ```
3.  **Ports Mapping Reference**:
    *   **Next.js App**: `http://localhost:3000` (API & Web App)
    *   **Grafana**: `http://localhost:3001` (Dashboards & Loki Logs explorer)
    *   **Jaeger UI**: `http://localhost:16686` (OTLP Tracing tool)
    *   **Prometheus**: `http://localhost:9090` (Raw time-series database metrics)
    *   **Loki API**: `http://localhost:3100` (Log storage)

### B. Run the Bulk Test Suite (18 Elliot Accounts)
We have written an automated test script that signs up, onboards, logs in, and configures mock Stripe accounts for 18 distinct users under the name structure `elliot-1` through `elliot-18`:

1.  Run the test script directly from your terminal:
    ```bash
    ./infra/scripts/test-observability.sh
    ```
2.  The script will output JSON responses for each step and print out a snippet of the Prometheus metrics at the end verifying that the data has been registered.

### C. Verify Logs in Grafana (Loki & Promtail)
1.  Open **`http://localhost:3001`** (User: `admin` / Password: `admin`).
2.  Click on the **Explore** tab in the left-hand sidebar.
3.  In the datasource dropdown menu in the top-left, select **Loki**.
4.  In the LogQL query bar, execute the following queries:
    *   **Show all logs generated by the script**:
        ```logql
        {app=~"timeguild-app-dev.*"}
        ```
    *   **Filter for signups**:
        ```logql
        {app=~"timeguild-app-dev.*"} |= "SIGNUP"
        ```
    *   **Filter for logins**:
        ```logql
        {app=~"timeguild-app-dev.*"} |= "LOGIN"
        ```
    *   **Filter for Stripe events**:
        ```logql
        {app=~"timeguild-app-dev.*"} |= "STRIPE"
        ```
    *   **Filter for tenant creations**:
        ```logql
        {app=~"timeguild-app-dev.*"} |= "TENANT"
        ```

### D. Verify Metrics in Prometheus
1.  Navigate to **`http://localhost:9090`**.
2.  In the query editor, type:
    ```prometheus
    timeguild_users_total
    ```
3.  Click **Execute**, then select the **Table** tab.
4.  You should see 18 new metrics records corresponding to each tenant:
    ```text
    timeguild_users_total{role="creator",tenant="elliot-1"} 1
    timeguild_users_total{role="creator",tenant="elliot-2"} 1
    ...
    timeguild_users_total{role="creator",tenant="elliot-18"} 1
    ```

### E. Verify Request Tracing in Jaeger
1.  Navigate to **`http://localhost:16686`**.
2.  Under **Service**, select `timeguild-app`.
3.  Under **Operation**, select `POST /api/auth/signin` or `POST /api/stripe/connect`.
4.  Click **Find Traces** and inspect trace timeline trees to analyze exact latencies.

---

## 4. Educational Reference Materials

*   **ArgoCD Multi-Tenancy Principles**:
    [https://oneuptime.com/blog/post/2026-01-27-argocd-multi-tenancy/view](https://oneuptime.com/blog/post/2026-01-27-argocd-multi-tenancy/view)
*   **Stripe Connected Onboarding Flows**:
    [https://docs.stripe.com/connect/hosted-onboarding](https://docs.stripe.com/connect/hosted-onboarding)
