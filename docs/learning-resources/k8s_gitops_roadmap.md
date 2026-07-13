# GitOps & Kubernetes Implementation Roadmap (7-Day Plan)

This roadmap details the step-by-step transition from your current **local Docker Compose** environment to a production-like, containerized, GitOps-managed **Kubernetes (K3s)** cluster running on an **AWS EC2 instance** with a **Namecheap domain** and **Elastic IP**.

To ensure you gain deep operational understanding and do not experience a "false sense of security," each day includes curated **study and reference materials** to help you learn and articulate the core concepts.

---

## Maturity Gap Analysis (Docker Compose ──> Kubernetes GitOps)

Your current Docker Compose setup is **highly mature for local development**:
*   Uses a multi-stage Alpine-based Bun Dockerfile for build/run.
*   Orchestrates Next.js, Redis, Postgres, and a complete observability stack (Prometheus, Loki, Promtail, Grafana, Jaeger) locally.
*   Uses volume mounts to enable live reloading of code.

### The Delta: What We Need to Build for Kubernetes
1.  **Image Distribution**: Move from local builds to pulling from a central registry (**Docker Hub**).
2.  **Infrastructure Host**: Replace local Docker daemon with an **AWS EC2 instance** running **K3s (lightweight Kubernetes)**.
3.  **DNS & Routing**: Replace port mappings (`3000:3000`) with a static **AWS Elastic IP** and a **Namecheap wildcard A-record** routing to a Kubernetes **Ingress controller (Traefik)**.
4.  **Deployment Controller**: Replace Docker Compose commands with **ArgoCD (GitOps)** tracking a packaged **Helm Chart**.
5.  **SSL/TLS**: Replace HTTP with **wildcard Let's Encrypt certificates** managed by `cert-manager` using Traefik's Default TLS Store.
6.  **Dynamic Namespace Provisioning (Completed)**: Implement code inside Next.js to talk to the K3s API server and spin up namespaces/pods dynamically.
7.  **Distributed Observability (Next Up)**: Re-configure Promtail/Prometheus to dynamically discover and label log and metric streams as new namespaces are spawned.

---

## 7-Day Roadmap Timeline

```text
               [ Day 1: Completed Setup ]
                           │
                           ▼
               [ Day 2: CI/CD & Docker Hub ]
                           │
                           ▼
               [ Day 3: EC2, EIP, & K3s Setup ]
                           │
                           ▼
               [ Day 4: Helm & ArgoCD GitOps ]
                           │
                           ▼
               [ Day 5: Wildcard SSL & TLS Store ]
                           │
                           ▼
               [ Day 6: Dynamic API Provisioner (Completed) ]
                           │
                           ▼
               [ Day 7: Observability Autodiscovery (Next Up) ]
```

---

## Day 1 — Completed Foundation
*   **Tasks Completed**: Username DNS-safe validation rules, database column migration scripts for SQLite and Postgres, Stripe Connect metadata mappings, and local observability testing.

---

## Day 2 — Production Containerization, Docker Hub, & CI/CD
*   **Goal**: Prepare the application container for cloud distribution and automate image building.
*   **Tasks**:
    1.  Validate the production-grade multi-stage [Dockerfile](file:///home/si3mshady/time-guild/Dockerfile) (ensuring standalone bundles fit K3s limitations).
    2.  Write a GitHub Actions CI/CD workflow (`.github/workflows/docker-publish.yml`) that automatically builds, tags, and pushes the production image to **Docker Hub** on every merge to main.
    3.  Modify your local `docker-compose.yaml` to pull and run this production image to verify container integrity without local workspace folder mounts.
*   **Study & Articulation Resources**:
    *   *Docker Multi-Stage Builds Guide*: [docs.docker.com/build/building/multi-stage/](https://docs.docker.com/build/building/multi-stage/)
    *   *GitHub Actions Docker Publish Guide*: [docs.github.com/en/actions/publishing-packages/publishing-docker-images](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
    *   *Bun Alpine Image Optimization*: [bun.sh/guides/runtime/docker](https://bun.sh/guides/runtime/docker)

---

## Day 3 — AWS EC2 Prep, Elastic IP, DNS, & K3s Installation
*   **Goal**: Spin up and configure your target cloud host environment.
*   **Tasks**:
    1.  Provision an **AWS Elastic IP (EIP)** and associate it with your EC2 instance.
    2.  Configure EC2 **Security Groups**: Open ports `80` (HTTP), `443` (HTTPS), and `6443` (Kubernetes API - restricted strictly to your local IP for security).
    3.  Log into your **Namecheap account** and create two DNS records pointing to your Elastic IP:
        *   `A Record` for `yourdomain.com`
        *   `Wildcard A Record` (`*`) for `*.yourdomain.com`
    4.  Install **K3s (lightweight Kubernetes)** on your EC2 instance using the quick-install script:
        ```bash
        curl -sfL https://get.k3s.io | sh -
        ```
    5.  Copy the kubeconfig file (`/etc/rancher/k3s/k3s.yaml`) to your local machine so you can run `kubectl` commands from your local CLI.
*   **Study & Articulation Resources**:
    *   *K3s Architecture and Quickstart Guide*: [docs.k3s.io/quick-start](https://docs.k3s.io/quick-start)
    *   *Understanding AWS Elastic IPs*: [docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
    *   *Namecheap: Setting Up Wildcard Subdomains*: [namecheap.com/support/knowledgebase/article.aspx/9769/2237/how-to-set-up-wildcard-subdomains/](https://www.namecheap.com/support/knowledgebase/article.aspx/9769/2237/how-to-set-up-wildcard-subdomains/)

---

## Day 4 — Helm Chart Refactoring & ArgoCD Setup on K3s
*   **Goal**: Establish a GitOps deployment engine that manages the core application using Helm.
*   **Tasks**:
    1.  Install **ArgoCD** into your K3s cluster.
    2.  Refactor the Helm chart templates in [infra/helm/timeguild](file:///home/si3mshady/time-guild/infra/helm/timeguild):
        *   Ensure it pulls the production image from your Docker Hub repository.
        *   Add Liveness and Readiness probes to `/api/healthz`.
        *   Configure Persistent Volume Claims (PVC) to persist `time_worth.db`.
    3.  Create an ArgoCD Application file (`infra/argocd/timeguild-app.yaml`) tracking the Helm chart in your Git repository.
    4.  Apply the ArgoCD manifest to trigger your first GitOps sync and verify your application is running on your EC2 instance.
*   **Study & Articulation Resources**:
    *   *ArgoCD Architectural Overview*: [argo-cd.readthedocs.io/en/stable/understand_concepts/](https://argo-cd.readthedocs.io/en/stable/understand_concepts/)
    *   *Helm Charts 101*: [helm.sh/docs/chart_template_guide/getting_started/](https://helm.sh/docs/chart_template_guide/getting_started/)
    *   *GitOps Deployment Principles*: [gitops.tech](https://www.gitops.tech/)

---

## Day 5 — cert-manager Wildcard SSL & Traefik Default TLS Store
*   **Goal**: Implement real HTTPS for all dynamic subdomains without copying certificate secrets.
*   **Tasks**:
    1.  Install **cert-manager** on your K3s cluster.
    2.  Delegate your Namecheap DNS Nameservers to **Cloudflare** (Free tier) to enable DNS-01 API integrations.
    3.  Configure a cert-manager `ClusterIssuer` using a Cloudflare API token.
    4.  Request a wildcard SSL certificate (`*.yourdomain.com`) in the K3s `kube-system` namespace.
    5.  Configure Traefik's `TLSStore` to use this wildcard certificate. This guarantees that any new tenant Ingress rules automatically get SSL without declaring individual TLS secrets.
*   **Study & Articulation Resources**:
    *   *ACME DNS-01 Cloudflare Issuer Setup*: [cert-manager.io/docs/configuration/acme/dns01/cloudflare/](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)
    *   *Traefik TLS Default Certificate Docs*: [doc.traefik.io/traefik/https/tls/#default-certificate](https://doc.traefik.io/traefik/https/tls/#default-certificate)
    *   *How Let's Encrypt DNS-01 Challenges Work*: [letsencrypt.org/docs/challenge-types/#dns-01-challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)

---

## Day 6 — Dynamic Namespace Provisioner (REST API integration - Completed)
*   **Goal**: Enable your Next.js application to dynamically spawn namespace clusters for registered users.
*   **Tasks Completed**:
    1.  Created a Kubernetes `ClusterRole` and `ClusterRoleBinding` granting your main Next.js Pod's ServiceAccount permissions to create and delete namespaces, deployments, services, and ingresses.
    2.  Wrote a Kubernetes REST API client helper in your Next.js codebase (using standard `fetch` with the pod's mounted service account token in `src/lib/k8s.ts`).
    3.  Updated the user registration endpoint: when a signup succeeds, Next.js calls the API to provision the `tenant-<username>` namespace and manifests in under 3 seconds.
    4.  Deployed and verified: Sign up a user and verify that `username.yourdomain.com` immediately loads their isolated container containerized page.
*   **Study & Articulation Resources**:
    *   *Kubernetes REST API reference*: [kubernetes.io/docs/reference/using-api/api-concepts/](https://kubernetes.io/docs/reference/using-api/api-concepts/)
    *   *Understanding Role-Based Access Control (RBAC)*: [kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
    *   *Accessing the K8s API Server from a Pod*: [kubernetes.io/docs/tasks/run-application/access-api-from-pod/](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/)

---

## Day 7 — Observability Auto-Discovery (Prometheus & Loki - Next Up)
*   **Goal**: Monitor log and metrics streams automatically as new tenant namespaces appear.
*   **Tasks**:
    1.  Deploy **Prometheus** and **Loki** to your K3s cluster.
    2.  Configure **Promtail** daemonsets with Kubernetes service discovery rules: when a pod in a `tenant-<username>` namespace is created, Promtail must scrape its logs and attach the `tenant` label automatically.
    3.  Configure Prometheus **ServiceMonitors** to scrape performance metrics per namespace using `namespaceSelector: any: true`.
    4.  Design a Grafana Dashboard template: Add a `tenant` dropdown menu so you can view isolated performance graphs, response rates, and Loki log streams for any specific user.
*   **Study & Articulation Resources**:
    *   *Promtail Kubernetes Discovery Configuration*: [grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config](https://grafana.com/docs/loki/latest/send-data/promtail/configuration/#kubernetes_sd_config)
    *   *Prometheus Operator ServiceMonitor Tutorial*: [prometheus-operator.dev/docs/user-guides/getting-started/](https://prometheus-operator.dev/docs/user-guides/getting-started/)
    *   *Grafana Dashboard Variables (Multi-Tenancy)*: [grafana.com/docs/grafana/latest/dashboards/variables/](https://grafana.com/docs/grafana/latest/dashboards/variables/)
