# TimeWorth GitOps & Infrastructure Study Guide

This guide is designed to help you master the architectural patterns, Kubernetes configurations, and bug workarounds we implemented today. It covers the "why" and "how" at both macro (architectural) and micro (technical) levels.

---

## 1. Repository Segregation: Mono-to-Multi Repo
We split the project into two directories on your local machine:
*   **App Code Directory**: `/home/si3mshady/time-guild`
*   **GitOps Config Directory**: `/home/si3mshady/time-guild-gitops`

### Micro Level: Preventing CI/CD Loops
*   **The Problem**: A typical CI/CD workflow triggers on every push to `main`. When code changes, the pipeline runs, builds a container image, and tags it (e.g. `image:sha-abc123`). The pipeline then updates the Helm chart configuration with the new tag and commits it.
*   **The Loop**: If config and code are in the same repo, this automated tag commit triggers the pipeline *again*, creating a new image, making a new commit, and loop-building infinitely.
*   **The Solution**: Decoupled repos break this loop. Pushing code to `time-guild` builds the image and pushes the tag commit to the *other* repo (`time-guild-gitops`). Since the GitOps repo has no build pipelines, the chain ends cleanly.

### Macro Level: Operational Security & Declarative Recovery
*   **Blast Radius Reduction**: Developers only need write access to the app code repo. They do not need write credentials to the live cluster control plane or DNS configs. If a developer's machine is compromised, the threat is isolated.
*   **Declarative Recovery**: If your Kubernetes cluster crashes, you don't rebuild code. You boot a fresh cluster, point ArgoCD to the `time-guild-gitops` repository, and the entire production environment restores itself (namespaces, routing, SSL certificates, database mounts) in under 2 minutes.

---

## 2. ArgoCD & Kubernetes Interaction
ArgoCD operates on the **declarative GitOps model**. Git is the single source of truth; ArgoCD continuously monitors Git and reconciles the live cluster state to match it.

### The ApplicationSet Pattern (Dynamic Generation)
Instead of hardcoding and maintaining static, manual Application files for every namespace (the "App of Apps" pattern), we use the **ApplicationSet controller** to dynamically generate and template environment deployments.
*   **The ApplicationSets** ([applicationset.yaml](file:///home/si3mshady/time-guild-gitops/infra/applicationsets/applicationset.yaml)) define generators that scan lists of environments and output corresponding Application specs.
*   We split the setup into two ApplicationSets:
    1.  `timeguild-auto-environments`: Generates `timeguild-dev` and `timeguild-staging` with automated pruning and self-healing.
    2.  `timeguild-manual-environments`: Generates `timeguild-prod` with manual sync policy for controlled staging-to-production promotions.

---

## 3. Cert-Manager Wildcard SSL & Traefik TLSStore
To provide secure HTTPS routes out-of-the-box for all dynamic creator subdomains (e.g., `https://avery.dev.timeguild.local`), we implemented a wildcard certificate framework.

### Let's Encrypt Rate Limits (The Macro Problem)
Let's Encrypt imposes a strict rate limit of **50 unique certificates per domain per week**. If you request a separate certificate for every subdomain client, you will hit this limit at scale, causing security warnings for new sign-ups.

### Wildcard CA Solution (The Micro Implementation)
We resolved this by generating a single wildcard certificate (`*.timeguild.local`, `*.timeguild.lab`, `*.timeguild.com`).
1.  **cert-manager**: Manages the lifecycle of certificates.
2.  **Local CA ClusterIssuer**: Established a self-signed root certificate authority (`timeguild-ca`) in the cluster, acting as our own local Let's Encrypt.
3.  **Wildcard Certificate** ([wildcard-certificate.yaml](file:///home/si3mshady/time-guild-gitops/infra/kubernetes/wildcard-certificate.yaml)): Generates the `wildcard-tls-secret` inside the `kube-system` namespace.
4.  **Traefik Default TLSStore** ([traefik-tlsstore.yaml](file:///home/si3mshady/time-guild-gitops/infra/kubernetes/traefik-tlsstore.yaml)): Tells the Traefik ingress controller: *"If any Ingress requests HTTPS but doesn't specify a secret, serve them this wildcard certificate."* This prevents us from duplicating certificate secrets across namespaces.

---

## 4. Deep Dive: Resolved Bugs
Here is what failed and how we fixed it:

| Bug | Cause | Fix |
| :--- | :--- | :--- |
| **ArgoCD PVC Deadlock** | PVC was in wave `0` and Deployment in wave `2`. But the local-path volume used `WaitForFirstConsumer` (meaning PVC stays `Pending` until a pod mounts it). ArgoCD refused to apply wave `2` because wave `0` was not healthy. | Moved the PVC to wave `2` in [pvc.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/pvc.yaml) so they are applied together. |
| **SQLite subPath Folder Bug** | Mounting a file via `subPath` from an empty volume forces Kubernetes to create a *directory* at that path, which blocks SQLite from creating a database file. | Mounted the volume to the directory `/app/data` and pointed SQLite to `/app/data/time_worth.db` via env variable. |
| **Probe Port Mismatch** | Next.js listened on port `80` (configured via ConfigMap), but `deployment.yaml` hardcoded `containerPort: 3000` for health probes, causing liveness checks to fail. | Dynamically mapped `containerPort` to the Helm service port (`80`) in [deployment.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/deployment.yaml). |
| **NetworkPolicy Port Block** | The NetworkPolicy was hardcoded to only allow ingress traffic on port `3000`. Traefik traffic on port `80` was blocked, returning 502s. | Aligned the allowed ingress port in [networkpolicy.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/networkpolicy.yaml) with the dynamic service port (`80`). |
| **Stripe Malformed Key Error** | Committing raw Stripe secret keys (`sk_test_*`) was blocked by GitHub Secret Scanning. Placeholders were used, which failed on live calls. | Added `ignoreDifferences` in the Application specs to tell Argo CD to ignore the Secret `data` field, then patched the real secrets directly on the cluster. |

---

## 5. Non-Hallucinated Study Search Prompts
Since search tools can sometimes return outdated or hallucinated URLs, use the following exact queries in Google or Kagi to read real blogs, articles, and documentation:

```text
"GitOps split code and configuration repository pattern"
"ArgoCD App of Apps pattern bootstrap cluster"
"Kubernetes volumeBindingMode WaitForFirstConsumer sync wave deadlock"
"Traefik TLSStore default certificate wildcard"
"cert-manager self-signed clusterissuer local development ca"
"ArgoCD ignoreDifferences secret data patch"
```

---

## 6. Next Steps per Directory

### In the Application Code Directory (`/home/si3mshady/time-guild`)
1.  **Configure GitHub Secret**: Open your GitHub repository settings and add a Secret named `GITOPS_PAT`. Set it to your Personal Access Token so the promotion workflow can commit to the GitOps repo.
2.  **Marketplace Validation**: You can now test account creation and connecting Stripe payouts. We refactored all categories to fully comply with Stripe rules.

### In the GitOps Directory (`/home/si3mshady/time-guild-gitops`)
1.  **ApplicationSets Rollout**: We successfully applied the `applicationset.yaml` manifest containing the split ApplicationSets. This dynamically generates the dev, staging, and production environments in the cluster.
2.  **Production DNS Challenge (Optional)**: When ready to delegate DNS to Cloudflare, swap `clusterissuer.yaml` to authenticate with Let's Encrypt using Cloudflare API tokens (detailed in `day5.md`).
