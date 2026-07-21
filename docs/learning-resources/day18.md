# Day 18: AI FinOps, Token Cost Tracing & Security Guardrails

> [!WARNING]
> **Status: OUTSTANDING (Future Phase)**

---

## 1. Architectural Rationale: Why We Do This
Integrating serverless LLM agents (DeepSeek API, LangGraph) into a multi-tenant platform introduces variable operational costs and potential security vectors. 
* **Token Cost Attribution**: Platform operators must track token usage and cost per tenant, model, and tool invocation to maintain positive margins.
* **AI Security Guardrails**: Protecting agent endpoints from prompt injections, unexpected tool calls, and PII leakage ensures system safety and trust.

---

## 2. Core Tasks

### A. Token Cost Attribution Telemetry
Instrument AI agent route handlers (`/api/agent/schedule`, `/api/agent/supervisor`) with Prometheus metrics:
* `timeguild_llm_tokens_total`: Counter tracking prompt and completion tokens grouped by `{tenant, model, action}`.
* `timeguild_llm_cost_cents_total`: Calculated cost metric in cents based on model token pricing tiers.

### B. AI FinOps Grafana Dashboard
Build visual Grafana panels:
* Real-time LLM cost spend vs platform commission revenue.
* Token consumption breakdown per tenant and sub-agent (`provider_setup`, `client_booking`, `lifecycle_support`).

### C. AI Security Guardrails Middleware
Implement lightweight security layer for LLM inputs and outputs:
* **Prompt Injection Detection**: Filter malicious user prompts attempting system instruction overrides or unauthorized tool calls.
* **PII Sanitization & Moderation**: Scrub sensitive client data before forwarding payloads to LLM APIs.

### D. AI SRE Incident Summarization Agent
Deploy an automated SRE agent hook:
* Monitor Loki error log bursts.
* Synthesize error stacks and emit structured incident summaries to administrative channels.

---

## 3. Study & Reference Materials
* **LangChain / LangGraph Observability**: Tracing agent steps and token consumption:  
  [https://js.langchain.com/docs/how_to/callbacks_async/](https://js.langchain.com/docs/how_to/callbacks_async/)
* **OWASP Top 10 for LLM Applications**: Key security risks and mitigation practices for AI systems:  
  [https://owasp.org/www-project-top-10-for-large-language-model-applications/](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
