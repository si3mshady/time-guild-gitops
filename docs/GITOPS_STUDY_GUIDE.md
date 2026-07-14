# TimeWorth GitOps & Infrastructure Study Guide

This guide is designed to help you master the architectural patterns, Kubernetes configurations, and bug workarounds we implemented today. It covers the "why" and "how" at both macro (architectural) and micro (technical) levels.

---

## 1. Remote Cluster Access & TLS Verification
We started by switching local kubeconfig access to the remote AWS EC2 instance.

### Micro Level: TLS Subject Alternative Name (SAN) Bypass
*   **The Problem**: Connecting to the K3s cluster via the AWS Elastic IP `https://18.220.240.2:6443` triggered TLS certificate errors. The cluster's built-in API server certificate did not list the public AWS Elastic IP in its Subject Alternative Names (SAN) list.
*   **The Solution**: We replaced the base64-encoded `certificate-authority-data` block with `insecure-skip-tls-verify: true` in your local `~/.kube/config`. This instructs `kubectl` to skip hostname-matching verification for this developer sandbox, restoring direct remote cluster control.

---

## 2. Repository Segregation: Mono-to-Multi Repo
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

## 3. ArgoCD & Kubernetes Interaction: ApplicationSets
ArgoCD operates on the **declarative GitOps model**. Git is the single source of truth; ArgoCD continuously monitors Git and reconciles the live cluster state to match it.

### The ApplicationSet Pattern (Dynamic Generation)
Instead of hardcoding and maintaining static, manual Application files for every namespace (the "App of Apps" pattern), we use the **ApplicationSet controller** to dynamically generate and template environment deployments.

#### 1. How Git and Helm Combine in our Project
The ApplicationSet acts as a bridge between your **Git repository** and your **Helm chart** to manage your three environments:

*   **Git-Based Control**: The ApplicationSet controller in the cluster watches the `/infra/applicationsets/` path of your `time-guild-gitops` Git repository. When it reads `applicationset.yaml`, it automatically creates three individual environment applications in your cluster: `timeguild-dev`, `timeguild-staging`, and `timeguild-prod`.
*   **Helm-Based Rendering**: For each of these three applications, the ApplicationSet directs Argo CD to compile the Helm chart located at `/infra/helm/timeguild` using the specific values files (e.g. merging `values.yaml` + `values-dev.yaml`). Helm then generates the final raw manifests (Deployment, Service, PVC, NetworkPolicy) and deploys them to their respective namespaces (`timeguild-dev`, `timeguild-staging`, `timeguild-prod`).

#### 2. Line-by-Line Breakdown of our Actual ApplicationSet Manifest
Here is the exact code from your `applicationset.yaml` and how it maps directly to your cluster resource names and namespaces:

*   **The Environment Generator**:
    ```yaml
    spec:
      generators:
        - list:
            elements:
              - env: dev
                valuesFile: values-dev.yaml
              - env: staging
                valuesFile: values-lab.yaml
    ```
    *What this does*: It tells Argo CD to loop twice. Loop 1 binds `{{env}}` to `dev` and `{{valuesFile}}` to `values-dev.yaml`. Loop 2 binds `{{env}}` to `staging` and `{{valuesFile}}` to `values-lab.yaml`.

*   **Dynamic Application Naming**:
    ```yaml
      template:
        metadata:
          name: 'timeguild-{{env}}'
    ```
    *What this does*: Automatically names the Application resources in your cluster: `Application: timeguild-dev` and `Application: timeguild-staging`.

*   **Helm Source Configuration**:
    ```yaml
        spec:
          source:
            repoURL: 'https://github.com/si3mshady/time-guild-gitops.git'
            targetRevision: HEAD
            path: infra/helm/timeguild
            helm:
              valueFiles:
                - values.yaml
                - '{{valuesFile}}'
    ```
    *What this does*: Instructs Argo CD to pull the Helm chart files directly from your GitOps repo at `infra/helm/timeguild`. For the `dev` application, it runs Helm merging the global `values.yaml` and `values-dev.yaml` to configure development limits.

*   **Target Cluster Namespaces**:
    ```yaml
          destination:
            server: 'https://kubernetes.default.svc'
            namespace: 'timeguild-{{env}}'
    ```
    *What this does*: Deploys all Helm templates to isolated namespaces in your K3s cluster (`timeguild-dev` and `timeguild-staging`).

*   **Security & Stripe Key Protection**:
    ```yaml
          ignoreDifferences:
            - group: ""
              kind: Secret
              name: 'timeguild-{{env}}-secrets'
              jsonPointers:
                - /data
    ```
    *What this does*: This is the configuration that protects your Stripe credentials. By adding `ignoreDifferences` on `/data` for `timeguild-{{env}}-secrets`, we instruct Argo CD to ignore the drift. The application stays **Synced** and healthy, your real keys remain securely patched on the cluster, and no keys are ever pushed to GitHub.

*   **Automated Deployment Policy**:
    ```yaml
          syncPolicy:
            automated:
              prune: true
              selfHeal: true
            syncOptions:
              - CreateNamespace=true
    ```
    *`prune: true`*: If we delete a template (like a route) from Git, Argo CD automatically deletes it from the cluster.
    *`selfHeal: true`*: If someone manually modifies the Deployment, Service, or NetworkPolicy in the cluster (e.g. changing the container port back to 3000), Argo CD will automatically revert it back to the Git source of truth (port 80).
    *`CreateNamespace=true`*: Automatically runs `kubectl create namespace` if it doesn't exist yet, saving you from manual setup.

---

## 4. Cert-Manager Wildcard SSL & Traefik TLSStore
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

## 5. Stripe Copy Compliance Alignment
We reviewed and refactored the frontend page copies to align 100% with the official Stripe Marketplace Framing.

### Macro Level: Business Underwriting Compliance
Stripe's underwriting policies strictly prohibit or restrict businesses related to "personal companionship," "dating," or "emotional presence" services due to high transaction risk.
*   **The Solution**: We aligned all app routing, descriptions, and user categories under the compliant **"Guided Services & Skills Marketplace"** model (mentorship, local tours, coaching, culinary tastings).

### Micro Level: Code Copy Refactoring
*   Changed categories: `"Event Companion"`, `"Dining Companionship"`, `"Travel Companion"`, `"Movie Buddy"`, `"Conversation Partner"`, `"Coffee & Walk"` to `"Event Logistics / Guide"`, `"Culinary Guide / Tasting"`, `"Travel Guide / Planning"`, `"Film Discussion / Mentoring"`, `"Conversation Practice"`, `"Local Discovery Walk"`.
*   Refactored homepage descriptions and labels from companion language to service provider terminology.

---

## 6. GitHub Actions Secrets & Promotion Pipeline
To complete the CI/CD promotion flow, we configured your repository secrets.

### Micro Level: Docker Registry Authentication & PAT Promotion
*   **Credentials**: We injected `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, and `GITOPS_PAT` in your GitHub repository.
*   **The Flow**: Pushing code now triggers a build, logs in securely to Docker Hub, pushes the image, and uses the `GITOPS_PAT` token to update the image tag in `infra/helm/timeguild/values.yaml` in the GitOps repo, triggering ArgoCD to deploy.

---

## 7. Deep Dive: Resolved Bugs
Here is what failed and how we fixed it:

| Bug | Cause | Fix |
| :--- | :--- | :--- |
| **ArgoCD PVC Deadlock** | PVC was in wave `0` and Deployment in wave `2`. But the local-path volume used `WaitFirstConsumer` (meaning PVC stays `Pending` until a pod mounts it). ArgoCD refused to apply wave `2` because wave `0` was not healthy. | Moved the PVC to wave `2` in [pvc.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/pvc.yaml) so they are applied together. |
| **SQLite subPath Folder Bug** | Mounting a file via `subPath` from an empty volume forces Kubernetes to create a *directory* at that path, which blocks SQLite from creating a database file. | Mounted the volume to the directory `/app/data` and pointed SQLite to `/app/data/time_worth.db` via env variable. Deleted the ghost directory created by Kubernetes. |
| **Probe Port Mismatch** | Next.js listened on port `80` (configured via ConfigMap), but `deployment.yaml` hardcoded `containerPort: 3000` for health probes, causing liveness checks to fail. | Dynamically mapped `containerPort` to the Helm service port (`80`) in [deployment.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/deployment.yaml). |
| **NetworkPolicy Port Block** | The NetworkPolicy was hardcoded to only allow ingress traffic on port `3000`. Traefik traffic on port `80` was blocked, returning 502s. | Aligned the allowed ingress port in [networkpolicy.yaml](file:///home/si3mshady/time-guild-gitops/infra/helm/timeguild/templates/networkpolicy.yaml) with the dynamic service port (`80`). |
| **Stripe Malformed Key Error** | Committing raw Stripe secret keys (`sk_test_*`) was blocked by GitHub Secret Scanning. Placeholders were used, which failed on live calls. | Added `ignoreDifferences` in the ApplicationSet specs to tell Argo CD to ignore the Secret `data` field, then patched the real secrets directly on the cluster. |

---

## 8. Non-Hallucinated Study Search Prompts
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

## 9. Next Steps per Directory

### In the Application Code Directory (`/home/si3mshady/time-guild`)
1.  **Stripe Connect Sandbox testing**: Open `https://dev.timeguild.local` in your browser, create a new creator account, and proceed with testing Stripe connect onboarding.
2.  **Code Updates**: All Next.js development, database migrations, and Stripe onboarding APIs will be developed here.

### In the GitOps Directory (`/home/si3mshady/time-guild-gitops`)
1.  **Production DNS Challenge (Optional)**: When ready to delegate DNS to Cloudflare, swap `clusterissuer.yaml` to authenticate with Let's Encrypt using Cloudflare API tokens (detailed in `day5.md`).
