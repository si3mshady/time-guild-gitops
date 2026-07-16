# Day 13: Observability Verification & End-to-End Testing

---

## 1. Architectural Rationale: Why We Do This
Validating system reliability before launching to real users requires observing both technical signals (latencies, errors) and business metrics (revenue, platform fees, booking success rates) side-by-side.
* **Business KPI Telemetry**: Exposing high-level financial metrics directly in Prometheus exposition format lets platform administrators monitor transaction volumes, payout splits, and pricing model usage.
* **End-to-End Simulation**: Running automated CLI scenarios simulating onboarding, booking, checkout, webhook callbacks, and final payouts verifies the system's resilience under realistic load.

---

## 2. Core Tasks

### A. Expose Business metrics
Add the following financial metric gauges to `src/app/api/metrics/route.ts`:
* `timeguild_platform_commission_dollars_total`: Cumulative platform commission fees retained (15% or 5%).
* `timeguild_provider_payouts_dollars_total`: Cumulative net payouts transferred to connected Express accounts.
* `timeguild_pricing_model_usage_total`: Counts grouped by `{type="flat"}` and `{type="hourly"}` to monitor popularity of models.

### B. Update Grafana dashboard ConfigMap
Edit the `timeguild-dashboard.yaml` manifest in `time-guild-gitops`:
* Add a financial metrics panel section visualizing platform commission margins, total payouts executed, and current escrow holdings.
* Add a gauge panel displaying the distribution of flat-rate vs. hourly bookings.
* Re-apply the updated ConfigMap to the cluster namespace.

### C. Run End-to-End Booking Simulation
Create a testing CLI script `/infra/scripts/test-e2e-bookings.sh` that:
* Signs up a new provider, onboards availability rules, and creates multiple slots.
* Signs up a customer, qualifications agent chat, and triggers Stripe Checkout.
* Sends mock webhook callbacks (`payment_intent.succeeded`) to verify state transitions and SCT transfers.

---

## 3. Study & Reference Materials
* **Prometheus Instrumenting Business Metrics**: Study how to instrument business KPIs safely:  
  [https://prometheus.io/docs/practices/instrumentation/](https://prometheus.io/docs/practices/instrumentation/)
* **Grafana Dashboard Panel Design**: Best practices for constructing single-pane dashboard grids:  
  [https://grafana.com/docs/grafana/latest/panels-visualizations/](https://grafana.com/docs/grafana/latest/panels-visualizations/)
