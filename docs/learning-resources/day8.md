# Day 8: Service Level Indicators (SLIs), Service Level Objectives (SLOs), and Prometheus Alerting Rules

---

## 1. Architectural Rationale: Why We Do This

As a Site Reliability Engineer (SRE), your main goal is to protect the **User Experience** while balancing development speed. We do this by defining clear targets:
1. **SLI (Service Level Indicator):** A quantitative measure of service performance. E.g., *"What percentage of payment webhooks succeeded?"*
2. **SLO (Service Level Objective):** The target reliability goal. E.g., *"99.9% of payment webhooks must succeed over any rolling 30-day window."*
3. **SLA (Service Level Agreement):** The legal commitment to users, including financial penalties if the SLO is breached. (SREs focus on SLOs to avoid breaching SLAs).

### Error Budgets
If your SLO is **99.9%**, your allowed failure rate is **0.1%**. This 0.1% is your **Error Budget**. 
* You can "spend" this budget on risk (deploying new features, updates, or minor downtime).
* If your budget burns too fast, feature deployments are frozen, and the team must focus 100% on stability.

---

## 2. Core Tasks

### A. Define SLIs/SLOs for Time Guild
We categorize targets based on our Critical and Tolerable Paths:

#### 1. Payment Webhook Reliability (Critical Path SLI)
*   **SLI:** $\frac{\text{Count of HTTP 200 webhook responses}}{\text{Total Count of incoming Stripe webhook requests}}$
*   **SLO:** 99.9% success rate over a rolling 30-day window.
*   **Metric:** `rate(timeguild_http_requests_total{path="/api/stripe/webhook", status="200"}[5m])` divided by `rate(timeguild_http_requests_total{path="/api/stripe/webhook"}[5m])`.

#### 2. Booking API Latency (Tolerable Path SLI)
*   **SLI:** $\frac{\text{Count of HTTP requests to /api/creators completed in < 500ms}}{\text{Total requests to /api/creators}}$
*   **SLO:** 95% of requests completed under 500ms over a rolling 30-day window.
*   **Metric:** `timeguild_http_request_duration_seconds_bucket{path="/api/creators", le="0.5"}`.

---

### B. Configure PrometheusRules in Kubernetes
To alert when an SLO is in danger of breaching, we declare a `PrometheusRule` resource in our monitoring namespace. Rather than alerting on single spike failures, we alert on **Error Budget Burn Rates** (e.g. if we are burning more than 2% of our monthly budget in 1 hour).

Example alerting rule (`prometheus-rules.yaml`):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: timeguild-alerts
  namespace: timeguild-monitoring
  labels:
    release: prometheus-stack
spec:
  groups:
    - name: timeguild-payment-alerts
      rules:
        - alert: StripeWebhookHighErrorRate
          expr: |
            sum(rate(timeguild_http_requests_total{path="/api/stripe/webhook", status!~"2.."}[5m])) 
            / 
            sum(rate(timeguild_http_requests_total{path="/api/stripe/webhook"}[5m])) > 0.01
          for: 2m
          labels:
            severity: critical
            tier: billing
          annotations:
            summary: "Stripe Webhook experiencing >1% error rate on namespace {{ $labels.namespace }}"
            description: "The payment processing webhook is failing. Escrow status transitions and payouts are blocked."
            runbook_url: "https://github.com/si3mshady/time-guild/blob/main/docs/runbooks/stripe-webhook-failures.md"
```

---

### C. Alertmanager Routing Configuration
Alertmanager receives alarms from Prometheus and routes them based on parameters:
*   **Critical Alerts (Severity: critical):** Paged immediately to on-call tools (e.g., PagerDuty, Slack).
*   **Warning Alerts (Severity: warning):** Routed to non-urgent channels (e.g., email or ticket queue).

---

## 3. Study & Reference Materials
*   **Google SRE Book - Chapter 4 (Service Level Objectives)**:  
    [https://sre.google/sre-book/service-level-objectives/](https://sre.google/sre-book/service-level-objectives/)
*   **Google SRE Book - Chapter 5 (Eliminating Toil)**:  
    [https://sre.google/sre-book/eliminating-toil/](https://sre.google/sre-book/eliminating-toil/)
*   **Alerting on SLOs (SRE Workbook)**: Learn how to set up multi-window multi-burn-rate alerts:  
    [https://sre.google/workbook/alerting-on-slos/](https://sre.google/workbook/alerting-on-slos/)
