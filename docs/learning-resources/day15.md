# Day 15: Codebase Testing Framework Restoration & E2E Validation

> [!WARNING]
> **Status: OUTSTANDING (Future Phase)**

---

## 1. Architectural Rationale: Why We Do This
Refactoring scheduling templates, availability rules windows, and dynamic slot-syncing introduces new business logic complexity. To prevent regressions and ensure marketplace payment integrations (connected Express account payout splits, checkouts) remain 100% stable, we must re-architect our automated testing framework.
* **Refactored Codebase Analysis**: Conduct a thorough audit of the new availability engine, booking state machine status paths, and telemetry exports.
* **Testing Framework Rebuild**: Develop an updated, reliable test suite in Vitest that covers our flexible booking lifecycle and database schema changes without legacy schema conflicts.

---

## 2. Core Tasks

### A. Codebase Architecture & State Audit
* Analyze and document the dynamic slot-syncing logic (`syncSlotsFromAvailability`) to establish bounds for test parameters (length, buffer times).
* Map all explicit booking state transitions to define happy-path and edge-case state validation tests.

### B. Rebuild Unit Test Suite
Write unit tests under `tests/unit/` covering:
* **Pricing & Commission Calculations**: Validate that commission rates correctly scale between 15% (new customer) and 5% (repeat customer).
* **Validation Guards**: Test duration constraints, timezone-safe slot ranges, and late cancellation window check functions.

### C. Rebuild Integration Test Suite
Write integration tests under `tests/integration/` covering:
* **Availability Rules Sync**: Test that adding/deleting recurring weekly blocks and overrides generates the correct chronological slots, respecting the weekly slot limit budgets.
* **Booking State Machine Transitions**: Assert that bookings transition from `draft` $\rightarrow$ `pending_payment` $\rightarrow$ `confirmed` $\rightarrow$ `completed` $\rightarrow$ `paid` correctly, rejecting invalid transition requests.
* **Stripe Webhook Simulation**: Mock payment capture webhooks to ensure booking confirmation status changes and slot reservations update as expected.
* **Stripe Connect Payout Splits**: Verify that connected account transfers split payouts (85% creator, 15% platform) according to trust rule notice timelines.

---

## 3. Study & Reference Materials
* **Vitest Mocking & Integration Testing Guide**: Techniques for mocking database drivers and external API boundaries:  
  [https://vitest.dev/guide/mocking.html](https://vitest.dev/guide/mocking.html)
* **Testing SQLite Database Transactions**: Best practices for resetting schema state between test hooks:  
  [https://www.sqlite.org/testing.html](https://www.sqlite.org/testing.html)
