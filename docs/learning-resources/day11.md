# Day 11: Booking Management & Rescheduling Workflows

---

## 1. Architectural Rationale: Why We Do This
High-trust marketplaces require clean transaction states. Both customers and providers must be able to cancel or reschedule bookings under clear, automated refund policies.
* **Booking State Machine**: Bookings transition through a predictable lifecycle: `draft` ➔ `awaiting_payment` ➔ `confirmed` (paid & secured in platform balance) ➔ `completed` (PIN check passed) ➔ `paid` (payout executed).
* **Late-Cancellation Enforcement**: Cancellations with 24h+ notice result in automatic 100% refunds and slot recovery. Cancellations with less than 24h notice are non-refundable, securing compensation for the provider.

---

## 2. Core Tasks

### A. Customer Booking dashboard
Build a client bookings interface:
* Create `/dashboard/bookings` displaying incoming and outgoing sessions, categorized by state.
* Add interactive "Reschedule" and "Cancel Booking" buttons to eligible confirmed sessions.

### B. Rescheduling API Route
Create `/api/bookings/reschedule` route handler:
* Verify request is initiated 24 hours prior to slot start time.
* Verify new slot is owned by the same creator and is currently `available`.
* Update the booking's `slot_id`, `booking_date`, and transaction records in a single database transaction. Transition old slot to `available` and new slot to `reserved`.

### C. Booking Cancellation Rules
Update cancellation methods in `src/lib/trust-rules.ts`:
* Ensure provider-initiated cancellations always return a 100% refund to the client.
* Ensure client-initiated cancellations check the 24h buffer: refund 100% if >=24h notice, payout provider 85% if <24h.

---

## 3. Study & Reference Materials
* **Airbnb Cancellation Policy Guidelines**: Review marketplace best practices for booking protections:  
  [https://www.airbnb.com/help/article/149](https://www.airbnb.com/help/article/149)
* **Transaction Isolation in SQLite**: Study database transaction consistency:  
  [https://www.sqlite.org/isolation.html](https://www.sqlite.org/isolation.html)
