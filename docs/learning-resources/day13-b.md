# Day 13-b: LangGraph Next.js Serverless Scheduling Agent Engine (DeepSeek API Integration)

> [!IMPORTANT]
> **Status: COMPLETED (Implemented & Verified)**

---

## 1. Architectural Rationale: Why We Do This

Using Next.js App Router built-in API Route Handlers ([src/app/api/agent/schedule/route.ts](file:///home/si3mshady/time-guild/src/app/api/agent/schedule/route.ts)), we run a full serverless **LangGraph stateful agent** powered by the **DeepSeek API (`deepseek-chat`)** via `@langchain/deepseek` directly behind an API endpoint without requiring a separate Python microservice or Express backend.

* **Single Codebase Simplicity**: Keeps client components, Next.js API routes, database schemas, and LangGraph AI agent logic in a unified TypeScript codebase.
* **DeepSeek LLM Integration**: Uses `@langchain/deepseek` (`model: "deepseek-chat"`) to evaluate client scheduling prompts, match timezone-safe slots, and format reasoning statements.
* **Stateful Agent Workflows**: LangGraph manages multi-step scheduling conversations, constraint evaluation, slot matching, and atomic DB lockouts cleanly via a compiled state machine.
* **Native Platform Integration**: The agent directly invokes server-side database modules ([src/lib/db.ts](file:///home/si3mshady/time-guild/src/lib/db.ts), [src/lib/availability.ts](file:///home/si3mshady/time-guild/src/lib/availability.ts)), creates Stripe checkout session URLs, and emits structured `[OBSERVABILITY]` events.

---

## 2. Implemented Architecture & Code Files

### A. LangGraph State Machine Architecture ([src/lib/agent/scheduling-graph.ts](file:///home/si3mshady/time-guild/src/lib/agent/scheduling-graph.ts))
Defines the stateful graph annotation and state machine nodes:
```typescript
import { StateGraph, Annotation, END, START } from "@langchain/langgraph";
import { ChatDeepSeek } from "@langchain/deepseek";
import db from "@/lib/db";
import { logObservabilityEvent } from "@/lib/observability";
```

Graph Execution Nodes:
1. `fetch_creator_constraints`: Reads creator session templates, pricing models, and available slots from SQLite.
2. `evaluate_slot_matches`: Uses **DeepSeek API (`deepseek-chat`)** via `@langchain/deepseek` to analyze client natural language prompts (e.g. "I need an afternoon session next week") against available creator time slots.
3. `lock_and_reserve_slot`: Executes atomic DB transaction marking slot as `'reserved'` and creating booking record with status `'pending_payment'`.
4. `generate_checkout_session`: Prepares Stripe Checkout Session parameters and generates checkout URL (`/stripe-mock-checkout?booking_id=...`).

### B. Serverless API Route Handler ([src/app/api/agent/schedule/route.ts](file:///home/si3mshady/time-guild/src/app/api/agent/schedule/route.ts))
* Exposes Next.js `POST /api/agent/schedule` endpoint executing `schedulingAgentGraph.invoke()`.
* Reads `DEEPSEEK_API_KEY` from environment variables.
* Zero external service container requirement—runs directly inside the Next.js App Router runtime.

### C. Observability & Telemetry Integration
* Emits structured `[OBSERVABILITY]` logs for agent state transitions (`event: booking_created`, `source: langgraph_deepseek_agent`, `status: pending_payment`).
* Exposes Prometheus telemetry metrics for agent execution latencies and successful booking reservations.

---

## 3. Testing & Verification

* **Local End-to-End Verification**: Executed automated workflow test creating a reservation `book_ag_...` with status `'pending_payment'`, slot reservation, observability log emission, and Stripe Checkout URL generation.
* **DeepSeek API Readiness**: Fully configured for `ChatDeepSeek` (`deepseek-chat`, `deepseek-reasoner`).
