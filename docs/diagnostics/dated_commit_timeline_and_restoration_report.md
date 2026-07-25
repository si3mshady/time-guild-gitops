# 📅 Chronological Commit Timeline & Restoration Diagnostic Report

> **Current Time:** July 25, 2026  
> **Repositories Audited:** `time-guild` (App Code) & `time-guild-gitops` (Deployment Infrastructure)

---

## 1. 📜 Chronological Commit History with Timestamps

### A. Application Repository (`time-guild`)

| Commit SHA | Date & Timestamp (ISO) | Commit Message / Action | State Category |
| :--- | :--- | :--- | :--- |
| **`b901913`** | `2026-07-25 14:18:53` | docs: Update Day 18 log with navigation header & auto-populated username fixes | Current `HEAD` |
| **`d2d0d26`** | `2026-07-25 14:18:37` | fix(flow): Connect application navigation header across creator page, auto-populate username | Navigation Update |
| **`606f527`** | `2026-07-25 14:15:27` | docs: Update Day 18 log with onboarding UI step transition fix | Documentation |
| **`ed1f477`** | `2026-07-25 14:15:04` | fix(onboarding): Instant step transition to creator profile form and unblock loading guard | Onboarding Patch |
| **`c29d1d8`** | `2026-07-25 07:07:22` | docs: Add Day 18 daily log summary for July 25, 2026 | Documentation |
| **`ebf9e55`** | `2026-07-25 07:03:20` | fix(ingress): Configure trusted wildcard-tls-secret and letsencrypt cluster-issuer for staging | TLS Ingress Fix |
| **`09cc3f6`** | `2026-07-25 06:51:05` | fix(nginx): Use dynamic connection_upgrade map to prevent ECONNRESET socket drops | Nginx Headers |
| **`1600d66`** | `2026-07-25 06:44:30` | fix(auth): Automatically derive fallback username from email during signup if omitted | Auth Fix |
| **`b7ff317`** | `2026-07-25 06:34:08` | perf(nginx): Enable Gzip compression and static asset immutable caching | Performance |
| **`e44bb3d`** | `2026-07-25 06:17:01` | fix(ci): Authenticate Docker logins prior to Buildx setup and upgrade build-push-action | CI Fix |
| **`39fd962`** | `2026-07-25 06:13:22` | perf: Eliminate startup spin latency (Nginx circuit breaker max_fails=0, OTEL guard) | Latency Fix |
| **`b6851ec`** | `2026-07-25 05:58:56` | fix(stripe): Simplify Stripe mode toggle between Simulated and Real Platform Mode | Stripe Toggle |
| **`380f71a`** | `2026-07-25 05:47:21` | fix(helm): Clear ingress hosts array in values-dev.yaml | Helm Fix |
| **`4e4581b`** | `2026-07-25 05:46:45` | fix(helm): Disable dev ingress route so staging handles timeguild.xyz when dev is scaled to 0 | Helm Ingress |
| **`6dd74f6`** | `2026-07-25 05:39:58` | chore: Scale dev deployment to 0 replicas and map timeguild.xyz to staging | Pod Scaling |
| **`79579c2`** | `2026-07-25 05:37:58` | perf(db): Enable WAL journal mode and busy_timeout for high SQLite concurrency | SQLite WAL |
| **`61ad9ba`** | `2026-07-25 05:22:13` | fix(auth): Synchronize client auth state immediately upon signup/signin | Auth Sync |
| **`29e8400`** | `2026-07-25 05:15:22` | chore: Scale prod deployment to 0 replicas to conserve cluster resources | Pod Scaling |
| **`eae1b70`** | `2026-07-25 04:52:17` | fix(onboarding): Batch availability seeding and optimize creator onboarding workflow | Onboarding Perf |
| **`c94f6c1`** 🌟 | `2026-07-25 04:06:58` | **[BASE WORKING STATE]** chore(helm & docs): Set single-replica defaults for local cluster | Original Baseline |
| **`bd315fd`** 🌟 | `2026-07-24 07:19:48` | **[PREVIOUS DAY WORKING STATE]** fix(ui): Permanently lock DialogContent bounds | July 24 Baseline |

---

## 2. 🔍 What Happened During Scaling & Edits

1. **July 25, 05:15–05:39 UTC** (`29e8400` & `6dd74f6`):
   - `timeguild-dev` and `timeguild-prod` were scaled down to 0 replicas.
   - `timeguild.xyz` was re-routed to `timeguild-staging`.
2. **July 25, 06:44–07:03 UTC** (`1600d66`, `09cc3f6`, `ebf9e55`):
   - Fixed Nginx `Connection: upgrade` headers causing REST API `ECONNRESET` drops.
   - Provisioned `wildcard-tls-secret` into `timeguild-staging` for trusted SSL.
3. **July 25, 14:15–14:18 UTC** (`ed1f477`, `d2d0d26`):
   - Adjusted `chooseRole` step transition and loading guard in `src/app/onboarding/page.tsx`.

---

## 3. ⏪ Time-Machine Restoration Procedure

To revert the application repository (`time-guild`) back in time to the exact baseline before today's changes:

### Step 1: Revert `time-guild` to Commit `bd315fd` (July 24 Baseline) or `c94f6c1` (July 25 04:06 Baseline)
```bash
cd /home/si3mshady/time-guild
git checkout main
git reset --hard bd315fd
git push origin main --force-with-lease
```

### Step 2: Scale `timeguild-dev` Back to 1 Replica
Update `values-dev.yaml` to set `replicaCount: 1` and enable `dev` ingress.

### Step 3: Re-Deploy and Sync ArgoCD
Trigger ArgoCD sync for `timeguild-dev` or `timeguild-staging`.
