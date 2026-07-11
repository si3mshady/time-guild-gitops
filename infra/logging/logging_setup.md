# Logging Setup (k3s Lightweight Stack)

## Executive Summary
For resource-constrained environments like a **k3s Home Lab**, a full ELK (Elasticsearch, Logstash, Kibana) stack consumes too much memory and CPU. We recommend **Grafana Loki** combined with **Promtail** (as a daemonset) as the lightweight logging stack. Loki acts as a metadata-indexed log repository, and Promtail aggregates container logs from stdout/stderr, forwarding them to Loki.

---

## Architecture Design

```text
Log Flow:
[Next.js App Server (stdout)] ──> [k3s Container Engine] ──> [Promtail DaemonSet] ──> [Grafana Loki] ──> [Grafana Visualizer]
```

---

## 1. Installation Commands (Helm)

To deploy Loki and Promtail in your k3s cluster, add the Grafana Helm repository and execute the following installs:

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Loki (Single-scale, filesystem storage)
helm upgrade --install loki grafana/loki \
  --namespace logging --create-namespace \
  --set loki.auth_enabled=false \
  --set loki.commonStorage.persisted_queries=true \
  --set singleBinary.replicas=1

# Install Promtail (Log shipper daemonset)
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --set config.clients[0].url=http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push
```

---

## 2. Promtail Custom Values Overrides
To scrape container logs from Next.js and format labels correctly, use this configuration:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logging
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    clients:
      - url: http://loki.logging.svc.cluster.local:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        pipeline_stages:
          - docker: {}
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app]
            action: keep
            regex: timeguild.*
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            action: replace
            target_label: container
```

---

## 3. Visualization in Grafana
1. Log into Grafana.
2. Navigate to **Connections -> Data Sources**.
3. Add a new **Loki** data source.
4. Set the URL to: `http://loki.logging.svc.cluster.local:3100` (or target ingress IP).
5. Open **Explore**, select Loki, and run LogQL queries to view real-time logs:
   ```logql
   {namespace="timeguild-prod", container="nextjs"}
   ```
