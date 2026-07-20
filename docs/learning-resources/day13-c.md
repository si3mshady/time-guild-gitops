# Day 13-c: LangGraph.js Supervisor Multi-Agent System & Domain Tools Architecture

> [!IMPORTANT]
> **Status: COMPLETED (Implemented & Verified)**

---

## 1. Architectural Rationale: Why We Do This

Using the **LangGraph.js Supervisor Pattern**, we separate AI orchestration from core domain logic. Rather than embedding AI directly into database models or replacing transactional endpoints, AI agents act as thin, stateful orchestrator clients that invoke canonical backend domain tools via Next.js server-side route handlers ([src/app/api/agent/supervisor/route.ts](file:///home/si3mshady/time-guild/src/app/api/agent/supervisor/route.ts)).

* **Domain Model Alignment**: Canonical booking state machine (`draft` → `pending_payment` → `confirmed` → `in_progress` → `completed` → `canceled` → `refunded`), Stripe Connect payouts, and SQLite schemas remain the ultimate source of truth.
* **Supervisor Router Pattern**: A central Supervisor agent classifies user intent and routes execution to specialized sub-agents (`provider_setup`, `client_booking`, `lifecycle_support`).
* **Thin Tool Wrappers**: Domain tools wrap existing backend service modules ([src/lib/db.ts](file:///home/si3mshady/time-guild/src/lib/db.ts), [src/lib/availability.ts](file:///home/si3mshady/time-guild/src/lib/availability.ts)) and preserve structured `[OBSERVABILITY]` logging.

---

## 2. Multi-Agent System Architecture

```text
 User Request (Provider Setup / Client Booking / Support Inquiry)
                                │
                                ▼
         POST /api/agent/supervisor (Next.js Route Handler)
                                │
                                ▼
        ┌───────────────────────────────────────────────┐
        │   Supervisor Router Agent (DeepSeek LLM)     │
        └───────────────────────┬───────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Provider Setup   │   │  Client Booking  │   │ Lifecycle Support│
│      Agent       │   │      Agent       │   │      Agent       │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘
         │                      │                      │
         ▼                      ▼                      ▼
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Provider Tools:  │   │  Client Tools:   │   │ Lifecycle Tools: │
│• get_listing     │   │• search_avail    │   │• get_booking_st  │
│• update_listing  │   │• create_booking  │   │• change_state    │
│• get_avail       │   │• initiate_payment│   │• query_payouts   │
│• update_avail    │   │                  │   │                  │
└────────┬─────────┘   └────────┬─────────┘   └────────┬─────────┘
         │                      │                      │
         └──────────────────────┼──────────────────────┘
                                │
                                ▼
                  Canonical Backend DB & Telemetry
```

---

## 3. Implemented Modules & File Locations

1. **Domain Tools Layer**:
   * **Provider Tools** ([src/lib/agent/tools/provider-tools.ts](file:///home/si3mshady/time-guild/src/lib/agent/tools/provider-tools.ts)):
     - `get_listing(providerId)`: Fetches pricing model, fixed duration, buffer time, max weekly slots.
     - `update_listing(providerId, params)`: Updates pricing mode (flat vs hourly) and budget rules.
     - `get_availability(providerId)`: Retrieves recurring availability windows and date overrides.
     - `update_availability(providerId, windows)`: Saves rules and runs dynamic 30-day slot sync (`syncSlotsFromAvailability`).
   * **Client Tools** ([src/lib/agent/tools/client-tools.ts](file:///home/si3mshady/time-guild/src/lib/agent/tools/client-tools.ts)):
     - `search_availability(providerId, queryDate)`: Returns available time slots.
     - `create_booking_draft(providerId, clientId, slotId)`: Atomically reserves slot and inserts booking with status `'pending_payment'`.
     - `initiate_stripe_checkout(bookingId)`: Prepares Stripe Checkout session URL (`/stripe-mock-checkout?booking_id=...`).
   * **Lifecycle Tools** ([src/lib/agent/tools/lifecycle-tools.ts](file:///home/si3mshady/time-guild/src/lib/agent/tools/lifecycle-tools.ts)):
     - `get_booking_state(bookingId)`: Reads canonical booking state and payment metadata.
     - `change_booking_state(bookingId, targetState, reason)`: Validates lifecycle transition (`canceled`, `confirmed`, `refunded`), releases slots on cancellation, and emits observability events.
     - `query_payouts(providerId)`: Calculates net creator payouts (85%) and platform commissions (15%).

2. **Supervisor Router & State Graph Machine** ([src/lib/agent/supervisor-graph.ts](file:///home/si3mshady/time-guild/src/lib/agent/supervisor-graph.ts)):
   * Compiles state graph using `@langchain/langgraph` + DeepSeek API (`@langchain/deepseek` / `ChatDeepSeek`).
   * Evaluates intent and conditionally routes execution to sub-agent nodes.

3. **Supervisor API Endpoint** ([src/app/api/agent/supervisor/route.ts](file:///home/si3mshady/time-guild/src/app/api/agent/supervisor/route.ts)):
   * Exposes Next.js `POST /api/agent/supervisor` for external clients and dashboard chat widgets.

---

## 4. Verification & Observability

* **End-to-End Workflow Testing**: Validated intent routing and tool execution for provider setup, client booking, slot locking, and cancellation state transitions.
* **Observability Event Stream**: All domain tool invocations emit structured `[OBSERVABILITY]` events (`listing_updated`, `availability_updated`, `booking_created`, `payment_initiation`, `booking_cancelled`).
