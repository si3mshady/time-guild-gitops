# Day 7: Observability Auto-Discovery in Dynamic Namespaces

> [!NOTE]
> **Status: COMPLETED**

---

## 1. Architectural Rationale: Why We Do This

*   **Observability Autodiscovery**: Traditional monitoring uses static scrapers (e.g. telling Prometheus to scrape `ip-address-1`, `ip-address-2`). In a dynamic SaaS cluster where customer namespaces (`tenant-avery`, `tenant-marcus`) are created and destroyed automatically, static configurations fail. We must use Kubernetes Service Discovery to instruct Prometheus and Promtail to automatically listen to API event streams and discover new pods as they spin up.
*   **Promtail Relabel Configs**: By default, Promtail scrapes all container stdout logs. To isolate logs per tenant, we write relabeling regex rules. When Promtail detects a container running in a namespace named `tenant-<username>`, it automatically extracts the `<username>` portion, maps it to a custom label `tenant`, and ships the stream to Loki. This lets us query and filter logs strictly by tenant name.
*   **Prometheus ServiceMonitors**: Part of the Prometheus Operator pattern. Instead of configuring Prometheus directly, you declare a `ServiceMonitor` resource. It tells Prometheus to scan all namespaces for pods matching a specific label (like `app: timeguild`) and start scraping their metrics (`/api/metrics`) dynamically.
*   **Grafana Multi-Tenant Dashboards**: Instead of building a separate dashboard for each creator, we build a single unified dashboard and configure a **dynamic variable query**. This queries Prometheus for all active tenant names and displays them as a dropdown menu. Selecting a creator instantly filters the metrics, Loki log streams, and Jaeger traces for just that user, keeping performance monitoring clean and organized.

---

## 2. Core Tasks

### A. Configure Promtail Namespace Auto-Discovery
Update your Promtail daemonset configs:
*   Add a `relabel_config` scraper job (detailed in [k8s_gitops_playbook.md](file:///home/si3mshady/time-guild/docs/learning-resources/k8s_gitops_playbook.md#L250-L270)) that matches namespaces matching `tenant-(.*)`.
*   This automatically attaches the `tenant` label to Loki streams as namespaces are spawned, allowing you to filter logs in Grafana by user.

### B. Deploy Prometheus ServiceMonitors
Configure ServiceMonitors to automatically scrape metrics:
*   Create a `ServiceMonitor` targeting `app: timeguild` pods in any namespace selector.
*   Whenever a Next.js pod starts up, Prometheus registers its metrics route (`/api/metrics`) and begins recording response latencies and registration metrics.

### C. Build Dynamic Grafana Dashboards
Design a unified dashboard panel in Grafana:
*   Create a dashboard template variable for `tenant`.
*   Configure the variable query: `label_values(timeguild_users_total, tenant)`.
*   This generates a dynamic dropdown menu, allowing you to select a specific tenant to filter graphs and Loki logs.

---

## 3. Study & Reference Materials
*   **Promtail Configuration Reference**: Learn how service discovery matches metadata to labels in container stdout streams:  
    [https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config](https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config)
*   **Prometheus Operator ServiceMonitors**: Learn how custom resource definitions automate Prometheus metric target additions:  
    [https://prometheus-operator.dev/docs/user-guides/getting-started/](https://prometheus-operator.dev/docs/user-guides/getting-started/)
*   **Grafana Dashboard Variables**: Study how to build dashboard templates using dropdown queries:  
    [https://grafana.com/docs/grafana/latest/dashboards/variables/](https://grafana.com/docs/grafana/latest/dashboards/variables/)
*   **Interactive SRE Course & Guides** (Local References):
    *   **[SRE Course Guide](file:///home/si3mshady/time-guild/SRE_COURSE_GUIDE.md)**: Conceptual deep dives on distributed tracing, low-cardinality indexing, and stateful circuit breakers.
    *   **[SRE Case Study & LinkedIn Post](file:///home/si3mshady/time-guild/SRE_LINKEDIN_POST.md)**: Macro and micro reasons for observability autodiscovery in multi-tenant SaaS environments.
