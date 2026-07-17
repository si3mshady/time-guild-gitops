# Day 10: Payment Consistency & Stripe Connect Verification

> [!NOTE]
> **Status: COMPLETED**

---

## 1. Architectural Rationale: Why We Do This
Marketplace pricing configurations must map cleanly to customer checkout sessions, transfer group definitions, and connected account transfers.
* **Pricing Consistency**: If a provider chooses a flat-rate session, the checkout total is constant. If hourly pricing is selected, the total must scale dynamically by duration.
* **Stripe Connect SCT Architecture**: Time Guild uses Separate Charges and Transfers. Payments are processed by the platform, the platform fee (15% base commission) is retained, and the remainder is transferred to the creator's connected Express account. Idempotent keys protect against double-transfers in distributed execution context.

---

## 2. Core Tasks

### A. Refactor Checkout calculations
Modify `/api/stripe/checkout/route.ts`:
* Query the provider's `pricing_type` from `creator_profiles`.
* If flat-rate, calculate total checkout cost as `price_per_session`. Reject any duration scaling.
* If hourly, verify customer selected hours are within `min_duration_hours` and `max_duration_hours` limits, and calculate total checkout cost as `price_hourly * duration_hours`.

### B. Map Transfer Metadata
Add comprehensive tracking metadata to the Stripe Checkout session parameters:
```json
{
  "pricingType": "flat_rate",
  "serviceId": "consultation_60m",
  "durationHours": "1",
  "amountInCents": "30000",
  "platformFeeInCents": "4500",
  "payoutInCents": "25500"
}
```

### C. Verify Idempotent SCT Payout transfers
Update `src/lib/trust-rules.ts`:
* Ensure commission percentages (15% default, 5% repeat) calculate correctly.
* Pass `idempotencyKey: "transfer_booking_" + bookingId` to Stripe `stripe.transfers.create` requests to prevent duplicate payouts.

---

## 3. Study & Reference Materials
* **Stripe Connect V2 SCT Documentation**: Learn how separate charges and transfers allocate funds securely:  
  [https://docs.stripe.com/connect/separate-charges-and-transfers](https://docs.stripe.com/connect/separate-charges-and-transfers)
* **Idempotent API Requests**: Study Stripe's guide on preventing duplicate charges:  
  [https://docs.stripe.com/api/idempotent_requests](https://docs.stripe.com/api/idempotent_requests)
