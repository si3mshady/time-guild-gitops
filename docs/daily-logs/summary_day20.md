# Day 20 Action Plan & Architecture Roadmap: Stripe Marketplace Hardening, Dispute Reversals, Telephony Proxy & 1099-K Tax Ledger

> **Date:** July 26, 2026  
> **Status:** PLANNED & READY FOR EXECUTION 🟡  
> **Target Release:** Day 20  

---

## 🎯 Executive Summary & Day 20 Objectives

Based on the evaluation of official Stripe documentation ([Build a marketplace](file:///home/si3mshady/time-guild/reference/stripe-connect-guide/Build%20a%20marketplace%20_%20Stripe%20Documentation.pdf), [Create destination charges](file:///home/si3mshady/time-guild/reference/stripe-connect-guide/Create%20destination%20charges%20_%20Stripe%20Documentation.pdf)) and the current state of **TimeWorth** in `~/time-guild` (~95% functionally complete), **Day 20** focuses on completing the final **5% of core marketplace hardiness**:

1. **Dispute Resolution & Transfer Reversals**: Listen for `charge.dispute.created` webhooks and issue automated transfer reversals (`stripe.transfers.createReversal`) to protect platform liquidity.
2. **Skipped Transfer Telemetry & Retry Engine**: Detect `charge.updated` events when connected accounts lose transfer capabilities, logging skipped transfers into an admin retry queue.
3. **Provider KYC Slot Publishing Gate**: Enforce a strict server-side check requiring `charges_enabled === 1` and `details_submitted === 1` before a creator can publish public available slots.
4. **Session-Based Telephony Contact Masking Proxy**: Expand the Twilio voice agent layer with a custom double-blind session proxy mapping table (`session_masked_contacts`) avoiding deprecated Twilio Proxy APIs.
5. **Form 1099-K Tax Ledger & Threshold Monitoring**: Implement a SQL ledger view (`v_creator_1099k_ledger`) tracking annual gross payment volume and flagging accounts crossing state ($600) or federal ($20,000 / 200 txns) tax thresholds.

---

## 📋 Task Breakdown & Technical Specifications

### Task 1: Dispute Reversal Listener (`charge.dispute.created`)
* **Target File**: [src/app/api/stripe/webhook/route.ts](file:///home/si3mshady/time-guild/src/app/api/stripe/webhook/route.ts)
* **Logic**:
  * Parse incoming `charge.dispute.created` webhook payloads.
  * Extract `dispute.charge` ID and query corresponding booking record from SQLite.
  * If a transfer was already executed (`stripe_transfer_id` exists), trigger `stripe.transfers.createReversal(booking.stripe_transfer_id)`.
  * Transition booking status to `disputed` and send system chat notifications to both client and creator.

### Task 2: Skipped Transfer Telemetry & Admin Retry Engine
* **Target Files**: [src/app/api/stripe/webhook/route.ts](file:///home/si3mshady/time-guild/src/app/api/stripe/webhook/route.ts), [src/app/api/admin/dashboard/route.ts](file:///home/si3mshady/time-guild/src/app/api/admin/dashboard/route.ts)
* **Logic**:
  * Listen for `charge.updated` webhook events.
  * Detect skipped transfers (`transfer_data === null` while charge is completed).
  * Persist skipped transfer details into `skipped_transfers` table.
  * Add a `POST /api/admin/stripe/retry-transfer` endpoint allowing platform admins to re-trigger payouts once creator KYC is cleared.

### Task 3: Provider KYC Gate on Available Slots Publishing
* **Target File**: [src/app/api/slots/route.ts](file:///home/si3mshady/time-guild/src/app/api/slots/route.ts)
* **Logic**:
  * On slot creation (`POST /api/slots`), query `stripe_accounts` for the authenticated creator.
  * Require `charges_enabled === 1` and `details_submitted === 1`.
  * Return `403 Forbidden` with action instructions if the creator has not completed Stripe Express onboarding.

### Task 4: Custom Telephony Contact Masking Proxy (Twilio)
* **Target Files**: [src/app/api/voice/proxy/route.ts](file:///home/si3mshady/time-guild/src/app/api/voice/proxy/route.ts), [src/lib/db.ts](file:///home/si3mshady/time-guild/src/lib/db.ts)
* **Logic**:
  * Create `session_masked_contacts` table storing `(booking_id, client_id, creator_id, twilio_virtual_number, expires_at)`.
  * On incoming Twilio call/SMS to the virtual proxy number, query active session window and return TwiML forwarding to actual hidden cell phone number.

### Task 5: Form 1099-K Tax Ledger & Threshold View
* **Target Files**: [src/lib/db.ts](file:///home/si3mshady/time-guild/src/lib/db.ts), [src/app/dashboard/page.tsx](file:///home/si3mshady/time-guild/src/app/dashboard/page.tsx)
* **Logic**:
  * Construct SQL View `v_creator_1099k_ledger` grouping by `creator_id` and tax year (`STRFTIME('%Y', booking_date)`).
  * Compute `gross_payment_volume` (inclusive of fees), `transaction_count`, and boolean threshold flags (`state_threshold_exceeded`, `federal_threshold_exceeded`).
  * Expose 1099-K compliance badge in Admin Dashboard overview.

---

## 📊 Verification Matrix for Day 20 Completion

```text
TASK                                           VERIFICATION METHOD                       STATUS
---------------------------------------------------------------------------------------------------
1. Dispute Reversal Webhook                    Stripe CLI trigger charge.dispute.created  [ ] PENDING
2. Skipped Transfer Queue & Admin Retry        Simulated account restriction test         [ ] PENDING
3. KYC Gate on Slot Publishing                 Attempt slot creation on unverified creator[ ] PENDING
4. Twilio Custom Contact Masking Proxy         HTTP webhook TwiML response test           [ ] PENDING
5. 1099-K Tax Ledger View & Admin Metric       Query v_creator_1099k_ledger SQL view     [ ] PENDING
```

---

## 📁 Repository Directory Mapping

All work, documentation, and operational artifacts for this plan are indexed across the following workspace locations:

* **App Base Codebase**: `/home/si3mshady/time-guild/`
  * API Routes: `src/app/api/stripe/`, `src/app/api/slots/`, `src/app/api/voice/`
  * Core Business & Trust Rules: `src/lib/trust-rules.ts`, `src/lib/db.ts`, `src/lib/stripe.ts`
  * Daily Logs Directory: `docs/daily-logs/`
  * Diagnostics Directory: `docs/diagnostics/`
  * Runbooks Directory: `docs/runbooks/`
  * Reference & Domain Guidance: `reference/` and `reference/stripe-connect-guide/`
* **GitOps Deployment Base**: `/home/si3mshady/time-guild-gitops/`
  * Mirrored Daily Logs: `docs/daily-logs/`
  * Helm & Deployment Manifests: `infra/helm/`
