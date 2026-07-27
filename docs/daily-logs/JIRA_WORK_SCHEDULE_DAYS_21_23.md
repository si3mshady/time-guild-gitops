# 🎟️ Jira Work Schedule & Sprint Backlog: Days 21 – 23

> **Project Key:** `TIME`  
> **Target Release:** Days 21 – 23 Sprint Plan  
> **Status:** APPROVED & BACKLOG READY 🟢  

---

## 📅 DAY 21: SPRINT 1 – E2E TESTING & MARKETPLACE VALIDATION (TEST DAY)

### EPIC: `TIME-EPIC-01: Marketplace Quality Assurance & E2E Handshake Verification`

---

### 🟢 Story `TIME-201`: End-to-End Escrow Booking & Handshake PIN Verification
* **Issue Type**: 🟢 Story
* **Component**: `Booking Engine / Stripe Connect`
* **Story Points**: `5`
* **User Story**:
  > **As a** Client,  
  > **I want to** book an available creator slot, complete Stripe Checkout, and execute the PIN handshake,  
  > **So that** funds transition safely from platform escrow to the creator's connected Stripe account.

* **Acceptance Criteria**:
  1. Given an available slot, when a client completes checkout, the slot status transitions to `booked` and booking transitions to `confirmed`.
  2. Given a confirmed booking, when the provider inputs the client's 4-digit PIN and verifies GPS location within 500m, the status transitions to `completed`.
  3. Upon completion, `stripe.transfers.create` executes the 85% creator net share transfer and triggers Instant Payout.

* **Technical Tasks**:
  * [ ] `TIME-201-1`: Execute full manual checkout flow on test creator `avery`.
  * [ ] `TIME-201-2`: Test PIN verification API endpoint `/api/stripe/bookings/verify-pin` with GPS telemetry.
  * [ ] `TIME-201-3`: Verify Stripe Test Dashboard transfer group logs.

---

### 🟢 Story `TIME-202`: Stripe Connect KYC Gate & 403 Unverified Creator Validation
* **Issue Type**: 🟢 Story
* **Component**: `Slots API / Creator Onboarding`
* **Story Points**: `3`
* **User Story**:
  > **As a** Platform Operator,  
  > **I want** slot publishing blocked for creators who haven't completed Stripe Express onboarding,  
  > **So that** payout failure risks and unfillable bookings are eliminated.

* **Acceptance Criteria**:
  1. Given an unverified creator (`charges_enabled = 0`), when they attempt to create a slot, `POST /api/slots` returns `403 Forbidden`.
  2. The UI displays an explicit error toast directing the creator to complete Stripe Express onboarding.

* **Technical Tasks**:
  * [ ] `TIME-202-1`: Test slot creation with unverified creator `marcus` via UI and `curl`.
  * [ ] `TIME-202-2`: Verify `403 Forbidden` response payload and UI alert toast.

---

### 🟢 Story `TIME-203`: Webhook Dispute Reversal & Skipped Transfer Queue Stress Test
* **Issue Type**: 🟢 Story
* **Component**: `Admin Dashboard / Webhooks`
* **Story Points**: `5`
* **User Story**:
  > **As a** Platform Admin,  
  > **I want to** test simulated chargebacks and skipped transfer retries in the Admin Dashboard,  
  > **So that** platform balance liquidity is protected during financial disputes.

* **Acceptance Criteria**:
  1. Given a `charge.dispute.created` webhook, booking status updates to `disputed` and transfer reversal is logged.
  2. Given a skipped transfer in the Admin Alert Queue, clicking "Retry Transfer" re-executes the payout and clears the queue item.

* **Technical Tasks**:
  * [ ] `TIME-203-1`: Send mock `charge.dispute.created` webhook payload via `curl`.
  * [ ] `TIME-203-2`: Test manual "Retry Transfer" button in Admin Dashboard.

---

## 📅 DAY 22: SPRINT 2 – TWILIO TELEPHONY & CONVERSATION RELAY PRODUCTION CONFIGURATION

### EPIC: `TIME-EPIC-02: Twilio Production Telephony & Double-Blind Contact Masking`

---

### 🟢 Story `TIME-210`: Twilio Console Corporate Brand & A2P 10DLC Campaign Registration
* **Issue Type**: 🟢 Story
* **Component**: `Telecom Infrastructure / Twilio`
* **Story Points**: `8`
* **User Story**:
  > **As a** Platform Operator,  
  > **I want to** register our corporate brand and messaging use case in the Twilio Trust Hub,  
  > **So that** carrier pass-through fees are optimized and outbound SMS messages are not blocked by US telecom networks.

* **Acceptance Criteria**:
  1. Brand Profile and Campaign Use Case (Customer Support / Appointment Reminders) registered in Twilio Console.
  2. A2P 10DLC approval status reaches `VERIFIED`.

* **Technical Tasks**:
  * [ ] `TIME-210-1`: Submit Business EIN and Brand details in Twilio Trust Hub.
  * [ ] `TIME-210-2`: Register 10DLC Messaging Campaign for transactional session notifications.

---

### 🟢 Story `TIME-211`: Twilio Conversation Relay AI Screening Voice Webhook Hookup
* **Issue Type**: 🟢 Story
* **Component**: `AI Screening Agent / Twilio Voice`
* **Story Points**: `5`
* **User Story**:
  > **As a** Client calling a creator's public screening number,  
  > **I want to** interact with an AI voice agent that qualifies my booking intent,  
  > **So that** I receive a Stripe Checkout link via SMS upon successful screening.

* **Acceptance Criteria**:
  1. Twilio Studio Phone Number webhook configured to stream WebSocket/HTTP events to `/api/voice/[tenantId]`.
  2. AI Voice agent parses `setup`, `prompt`, and `interrupt` stream events and sends SMS booking links.

* **Technical Tasks**:
  * [ ] `TIME-211-1`: Configure Twilio Studio Flow pointing inbound voice calls to `/api/voice/[tenantId]`.
  * [ ] `TIME-211-2`: Perform live test call to verify AI voice qualification and SMS link dispatch.

---

### 🟢 Story `TIME-212`: Double-Blind Virtual Phone Number Pooling & Proxy Routing
* **Issue Type**: 🟢 Story
* **Component**: `Twilio Voice Proxy / Privacy Engine`
* **Story Points**: `5`
* **User Story**:
  > **As a** Client or Creator in an active session,  
  > **I want** my phone calls and text messages routed through a temporary proxy number,  
  > **So that** my personal cell phone number remains completely private.

* **Acceptance Criteria**:
  1. Inbound calls/SMS to virtual proxy numbers query `session_masked_contacts` for active non-expired sessions.
  2. The webhook returns TwiML `<Dial>` / `<Sms>` forwarding rules to actual hidden numbers during the session window.

* **Technical Tasks**:
  * [ ] `TIME-212-1`: Configure Twilio Messaging/Voice Webhook URL to point to `/api/voice/proxy`.
  * [ ] `TIME-212-2`: Test two-way masked SMS and voice call forwarding.

---

## 📅 DAY 23: SPRINT 3 – TIMEWORTH MOBILE APP ARCHITECTURE & REACT NATIVE / EXPO BLUEPRINT

### EPIC: `TIME-EPIC-03: Mobile Native App & Cross-Platform Expansion`

---

### 🟢 Story `TIME-220`: Mobile PWA & React Native / Expo Cross-Platform Architecture Blueprint
* **Issue Type**: 🟢 Story
* **Component**: `Mobile Client / React Native Expo`
* **Story Points**: `8`
* **User Story**:
  > **As a** Mobile User (Client or Expert),  
  > **I want** a dedicated iOS & Android mobile app built with React Native / Expo,  
  > **So that** I can manage bookings, view availability, and communicate seamlessly on mobile devices.

* **Acceptance Criteria**:
  1. Complete Expo SDK 51 mobile app project scaffolded in `apps/mobile` (or `time-guild-mobile`).
  2. Shared TypeScript API client and database models linked between Next.js web and Expo mobile.

* **Technical Tasks**:
  * [ ] `TIME-220-1`: Define Mobile App Architecture RFC document in `docs/architecture/mobile_app_blueprint.md`.
  * [ ] `TIME-220-2`: Scaffold Expo React Native app with Expo Router (file-based navigation).

---

### 🟢 Story `TIME-221`: Mobile Push Notifications for Instant PIN Handshake & Session Alerts
* **Issue Type**: 🟢 Story
* **Component**: `Mobile Push / Expo Notifications`
* **Story Points**: `5`
* **User Story**:
  > **As a** Creator or Client,  
  > **I want** native push notifications when a session is booked, confirmed, or ready for PIN check-in,  
  > **So that** I never miss a session start time or payout handshake.

* **Acceptance Criteria**:
  1. Expo Push Notifications service integrated with APNs (Apple) and FCM (Firebase/Android).
  2. Push notifications sent automatically on booking confirmation and session start.

* **Technical Tasks**:
  * [ ] `TIME-221-1`: Integrate `@expo/notifications` SDK and register device push tokens in SQLite database.
  * [ ] `TIME-221-2`: Add push notification trigger logic to `src/lib/trust-rules.ts`.

---

### 🟢 Story `TIME-222`: Mobile Wallet One-Tap Checkout (Apple Pay & Google Pay)
* **Issue Type**: 🟢 Story
* **Component**: `Mobile Checkout / Stripe Mobile SDK`
* **Story Points**: `5`
* **User Story**:
  > **As a** Mobile Client,  
  > **I want to** complete session booking using Apple Pay or Google Pay in one tap,  
  > **So that** checkout takes under 5 seconds without typing credit card numbers.

* **Acceptance Criteria**:
  1. `@stripe/stripe-react-native` SDK configured with PaymentSheet.
  2. One-tap Apple Pay and Google Pay checkouts execute with `transfer_group` escrow tracking.

* **Technical Tasks**:
  * [ ] `TIME-222-1`: Configure `@stripe/stripe-react-native` PaymentSheet with Apple Pay merchant ID.
  * [ ] `TIME-222-2`: Test native mobile checkout flow on iOS Simulator and Android Emulator.

---

## 📊 Sprint Summary Table

```text
SPRINT              DAY      EPIC KEY         STORIES INCLUDED               TOTAL POINTS
-----------------------------------------------------------------------------------------
Sprint 1 (Test Day) Day 21   TIME-EPIC-01     TIME-201, TIME-202, TIME-203   13 pts
Sprint 2 (Twilio)   Day 22   TIME-EPIC-02     TIME-210, TIME-211, TIME-212   18 pts
Sprint 3 (Mobile)   Day 23   TIME-EPIC-03     TIME-220, TIME-221, TIME-222   18 pts
```
