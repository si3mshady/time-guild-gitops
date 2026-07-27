# Day 21 Action Plan & Architecture Roadmap: Webhook Security Hardening & Raw Signature Verification

> **Date:** July 28, 2026  
> **Status:** PLANNED & SCHEDULED 🟡  
> **Target Release:** Day 21 (Pre-Beta Hardening Sprint 1)  

---

## 🎯 Executive Summary & Day 21 Objectives

As part of the even 5-day Pre-Beta Launch Ramp-Up, **Day 21** focuses on securing the payment gateway webhook infrastructure:

1. **Strict Production Webhook Signature Verification**: Update [src/app/api/stripe/webhook/route.ts](file:///home/si3mshady/time-guild/src/app/api/stripe/webhook/route.ts) to enforce raw request signature verification via `stripe.webhooks.constructEvent`.
2. **Rejection of Unsigned Payloads**: Eliminate unverified JSON parsing fallbacks in live and test modes, returning HTTP 400 `Webhook signature missing or invalid` for unverified requests.
3. **Webhook Security Logging**: Record signature validation telemetry in the `webhook_logs` table.

---

## 📋 Jira Story Alignment

* **`TIME-201`** (`5 pts`): Enforce Raw Body Webhook Signature Verification in `/api/stripe/webhook`
* **`TIME-202`** (`3 pts`): Reject Unsigned Webhook Payloads with HTTP 400 Response
* **`TIME-203`** (`3 pts`): Add Webhook Security Validation Telemetry to Admin Stream

---

## 📊 Verification Matrix for Day 21

```text
TASK                                           VERIFICATION METHOD                       STATUS
---------------------------------------------------------------------------------------------------
1. Raw Signature ConstructEvent                Stripe Webhook Signature Verification      [ ] SCHEDULED
2. Reject Unsigned Requests                    HTTP 400 Bad Request Test                  [ ] SCHEDULED
3. Security Telemetry Logging                  webhook_logs Table Inspection              [ ] SCHEDULED
```
