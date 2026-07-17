# Day 6: Dynamic Tenant Namespace Provisioning (REST API Integration)

> [!NOTE]
> **Status: COMPLETED**

---

## 1. Architectural Rationale: Why We Do This

*   **Tenant Compute Isolation (Namespace-per-User)**: In a multi-tenant SaaS application, running all customer scripts in the same namespace is a significant security risk. If a container is compromised or runs out of memory, it can affect or crash other tenants' services. Giving each creator their own Namespace isolates their CPU, memory, and container runtimes, ensuring a secure "sandbox" boundary.
*   **RBAC (Role-Based Access Control) Principle of Least Privilege**: By default, pods in a Kubernetes cluster cannot interact with the Kubernetes API. To allow your Next.js application to spawn namespaces and deployments, we must explicitly grant it permissions using a `ServiceAccount` and a `ClusterRoleBinding`. We limit these permissions strictly to the resources (namespaces, deployments, services, ingresses) and verbs (create, delete) required, keeping the cluster secure.
*   **Direct API Client (Bypassing GitOps Latency)**: While GitOps is excellent for static infrastructure, using it for real-time customer onboarding introduces latency (up to 3 minutes for Git/ArgoCD polling) and Git merge conflicts under high traffic. Using the Kubernetes REST API directly from your Next.js app enables **sub-second onboarding** while still utilizing standard Kubernetes resource isolated runtimes.
*   **Persistent Storage Sharing**: Because each pod runs in its own namespace, they cannot easily share local disk files. To allow multiple dynamic containers to access the SQLite `time_worth.db` file, we must mount a shared volume (using `ReadWriteMany` PVCs) or utilize a centralized cloud database (like Supabase Postgres) via environment variables.

---

## 2. Core Tasks

### A. Apply RBAC Permissions
Configure the Next.js service account permissions inside K3s to allow resource creation:
*   Apply the `ServiceAccount`, `ClusterRole`, and `ClusterRoleBinding` configurations (detailed in [k8s_gitops_playbook.md](file:///home/si3mshady/time-guild/docs/learning-resources/k8s_gitops_playbook.md#L110-L149)). This allows in-cluster pods to authenticate requests.

### B. Write K8s Client Helper in Next.js
Implement the REST client in `src/lib/k8s.ts` using standard node `fetch`:
*   The script reads `/var/run/secrets/kubernetes.io/serviceaccount/token` and issues HTTP POST commands to K3s internal endpoints to create a Namespace (`tenant-<username>`), Deployment, Service, and Ingress route.

### C. Connect Registration Webhooks
Integrate the provisioning function into the registration endpoint:
*   When a new creator account is registered, Next.js calls `provisionTenantNamespace(username, domain)`.
*   The system creates the infrastructure in under 3 seconds, mapping `username.yourdomain.com` directly to their container.

### D. Setup SQLite Database Volume Sharing
Because all tenant pods must read/write to the shared database, we configure a PersistentVolumeClaim (PVC) with `ReadWriteMany` permissions (supported by NFS or K3s local storage engines) to mount `/app/data/time_worth.db` across namespaces, or connect pods directly to Supabase Postgres.

---

## 3. Study & Reference Materials
*   **Kubernetes API Concepts**: Understand how REST resources correspond to cluster state changes:  
    [https://kubernetes.io/docs/reference/using-api/api-concepts/](https://kubernetes.io/docs/reference/using-api/api-concepts/)
*   **Role-Based Access Control (RBAC)**: Study how ClusterRoles, Rules, and Subjects authorize API access safely:  
    [https://kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
*   **Accessing the API from a Pod**: Understand how service account tokens are automatically injected into running containers:  
    [https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/](https://kubernetes.io/docs/tasks/run-application/access-api-from-pod/)

---

## 4. Real-World Lab Implementation Notes & Troubleshooting

### A. Bypassing GitOps Latency with In-Cluster REST API
We implemented real-time customer onboarding by making Direct REST API calls to the K3s API server from Next.js, bypassing GitOps commit/sync latency (~3 minutes). 
1.  **RBAC Config**: Bound a custom `ServiceAccount` (`timeguild-sa`) to a `ClusterRole` allowing namespace, deployment, service, and ingress creations.
2.  **In-Cluster Authentication**: Next.js automatically reads `/var/run/secrets/kubernetes.io/serviceaccount/token` and issues JSON payloads directly to `https://kubernetes.default.svc`.

### B. Decoupling Secrets from Helm Chart (Critical Conflict Fix)
*   **Conflict**: If credentials (like Stripe API keys) are defined inside the Helm chart templates (even with ArgoCD `ignoreDifferences` enabled), any automated deployment sync will re-render the chart templates and overwrite live in-cluster secret values back to Git repository defaults (`sk_test_placeholder`).
*   **Resolution**: 
    - Deleted the `secrets.yaml` template from Helm entirely.
    - Updated `deployment.yaml` to reference an unmanaged secret `timeguild-dev-env-secrets`.
    - Created an automation script `./infra/scripts/apply-env-secrets.sh` to build `timeguild-dev-env-secrets` directly from local `.env` variables, preventing any ArgoCD overrides.

### C. Wildcard Route Hijacking & Ingress Priority
*   **Conflict**: Because Traefik defaults to evaluating regexp rules (like `HostRegexp(*.timeguild.xyz)`) over exact matches due to string length routing rules, the wildcard ingress hijacked subdomain traffic (e.g. `elliott.timeguild.xyz`) and routed it to the marketplace instead of the creator pod.
*   **Resolution**: Added `traefik.ingress.kubernetes.io/router.priority: "10000"` to the dynamically created ingress. This forces Traefik to prioritize the exact subdomain match first.

### D. Portable SQLite Database Querying in Scripts
*   **Conflict**: Running developer scripts (like `trigger-provisioning.js`) inside node/bun runtimes can fail when loading native sqlite binaries (`better-sqlite3`) due to compilation target mismatches.
*   **Resolution**: Replaced the native module db querying logic with a portable python subprocess:
    ```javascript
    const { execSync } = require('child_process');
    const result = execSync("python3 -c 'import sqlite3; ...'").toString();
    ```
    This successfully queries the active sqlite database without introducing binary dependencies.
