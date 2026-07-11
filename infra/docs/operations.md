# Platform Operations & Administration Guide

This guide details runtime administrative operations for the **Time Guild / AURA** trust layer platform.

---

## 1. Database Operations (PostgreSQL)

Since Next.js connects to a decoupled PostgreSQL database, you can run database updates or inspect tables by executing SQL queries inside the database cluster:

### Accessing the PostgreSQL Command Line inside a Pod:
1. Find the active PostgreSQL StatefulSet pod:
   ```bash
   kubectl get pods -n timeguild-prod -l app=postgres
   ```
2. Exec into the pod:
   ```bash
   kubectl exec -it postgres-0 -n timeguild-prod -- psql -U postgres -d timeguild
   ```
3. Run queries to inspect the multi-tenant schema:
   ```sql
   -- View all user signups and connected accounts
   SELECT id, email, role, stripe_account_id FROM users;
   
   -- View all locked time-escrow bookings
   SELECT id, creator_id, status, price_paid, stripe_transfer_id FROM bookings;
   ```

---

## 2. Managing Stripe Connect Escrows & Disputes
The platform dashboard features an **Admin Overview** and a **Creators KYC Directory**:
1. Log into the dashboard at `https://app.timeguild.com/dashboard` using an administrator account.
2. Select the **Platform Admin Overview** tab.
3. Review the aggregate metrics:
   - **Total Gross Volume (GMV)**: Captured payments volume.
   - **Platform Escrow Balance**: Funds locked pending client PIN handshake.
   - **Net Platform Revenue**: The platform's commission share (15% standard, or 5% repeat customer loops).
4. Review the **Creators KYC Directory**:
   - Check if a creator's Connected Account has KYC validation completed.
   - Look for the green **KYC VERIFIED** badge or the red **KYC PENDING** alert.

---

## 3. SRE Observability & Monitoring Operations

### Accessing the Grafana Dashboard:
1. Retreive the Grafana admin user password:
   ```bash
   kubectl --namespace timeguild-monitoring get secrets prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
   ```
   *(Default User: `admin`)*
2. Forward the Grafana port locally:
   ```bash
   kubectl port-forward svc/prometheus-stack-grafana -n timeguild-monitoring 3000:80
   ```
3. Open a browser and navigate to `http://localhost:3000` to view the SRE metrics.

### Checking Webhook Logs and Metrics:
*   Navigate to the **Stripe Connect & Webhooks** dashboard in Grafana.
*   Monitor `timeguild_stripe_transfers_completed_total` (successful payouts) and `timeguild_stripe_escrow_refunds_total` (refunds) counters.
*   To view raw webhook event payloads stored in the database, query the `webhook_logs` table:
    ```sql
    SELECT event_type, created_at FROM webhook_logs ORDER BY created_at DESC LIMIT 10;
    ```

---

## 4. Resetting the Lab Database ("Nuke DB")
If you need to return the database to a clean, seeded state for a demo:
1. Click the floating **"Nuke DB"** button in the bottom right corner of the UI.
2. Confirm the action in the warning modal.
3. This triggers a POST request to `/api/admin/reset` which wipes bookings, chats, and custom slots, reseeding the three core expert profiles back to their default states.
