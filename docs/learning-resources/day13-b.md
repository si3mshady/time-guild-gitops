# Day 13-b: LangGraph Next.js Serverless Scheduling Agent Engine

> [!IMPORTANT]
> **Status: OUTSTANDING (Planned Active Phase - Next up after Day 13 UI)**

---

## 1. Architectural Rationale: Why We Do This

Using Next.js App Router built-in API Route Handlers (`src/app/api/agent/schedule/route.ts`), we can run a full serverless **LangGraph stateful agent** directly behind an API endpoint without needing a separate Python microservice or Express backend.

* **Single Codebase Simplicity**: Eliminates external microservice management overhead and keeps client, API routes, database schemas, and AI agent logic in a unified Next.js TypeScript codebase.
* **Stateful Agent Workflows**: LangGraph manages multi-step scheduling conversations, slot matching, constraint evaluation, and reservation lockouts cleanly via a compiled state machine.
* **Native Platform Integration**: The agent directly invokes server-side database helper modules (`src/lib/db.ts`, `src/lib/availability.ts`), Stripe checkout session creators, and Prometheus metrics telemetry (`/api/metrics`).

---

## 2. Core Implementation Roadmap

### A. LangGraph State Machine Architecture (`src/lib/agent/scheduling-graph.ts`)
Define the stateful graph interface:
```typescript
interface SchedulingState {
  messages: BaseMessage[];
  creatorId: string;
  clientId: string;
  preferredDateRange?: { start: string; end: string };
  durationMinutes?: number;
  matchedSlots: AvailableSlot[];
  selectedSlot?: AvailableSlot;
  bookingStatus: 'draft' | 'pending_payment' | 'failed';
  stripeCheckoutUrl?: string;
  error?: string;
}
```

Graph Execution Nodes:
1. `fetch_creator_constraints`: Reads creator session templates, fixed durations, buffer times, and recurring availability windows from `availability_windows`.
2. `evaluate_slot_matches`: Uses LLM intelligence / deterministic rule matching to identify optimal available time slots matching the client's request.
3. `lock_and_reserve_slot`: Executes atomic DB transaction marking slot as reserved and creating booking record with status `'pending_payment'`.
4. `generate_checkout_session`: Triggers Stripe Checkout Session creation and returns checkout URL for immediate client redirection.

### B. Next.js API Route Handler (`src/app/api/agent/schedule/route.ts`)
* Implements Next.js `POST` route handler executing the compiled LangGraph workflow.
* Handles request validation, auth token parsing, and response streaming/JSON formatting.
* Zero external service dependency—runs directly inside the Next.js serverless/Node runtime.

### C. Observability & Telemetry Integration
* Emits structured `[OBSERVABILITY]` logs for agent graph step transitions (`agent_scheduling_started`, `agent_slot_matched`, `agent_booking_reserved`).
* Exposes Prometheus telemetry metrics:
  - `timeguild_agent_scheduling_requests_total`
  - `timeguild_agent_scheduling_latency_seconds`
  - `timeguild_agent_successful_reservations_total`

---

## 3. Study & Reference Materials
* **LangGraph JS / TS Documentation**: State graph compilation and agent orchestrations in TypeScript:  
  [https://langchain-ai.github.io/langgraphjs/](https://langchain-ai.github.io/langgraphjs/)
* **Next.js App Router API Routes**: Building robust server-side endpoint handlers:  
  [https://nextjs.org/docs/app/building-your-application/routing/route-handlers](https://nextjs.org/docs/app/building-your-application/routing/route-handlers)
