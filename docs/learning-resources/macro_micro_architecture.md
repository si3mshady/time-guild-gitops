# Macro & Micro Architecture Playbook: How ArgoCD, Helm, K3s, and Next.js Cooperate

This document provides a highly granular, explicit explanation of the system architecture. It is designed to be reverse-engineered so you can reproduce it on any future production project.

---

## 1. High-Level Macro Architecture (The Big Picture)

The system is split into two distinct repositories to separate the **Application Code** from the **Infrastructure State (GitOps)**:

```
[ Developer Workspace ]                 [ GitOps Workspace ]
  (time-guild repo)                       (time-guild-gitops repo)
         │                                       │
         ├─► Git Push (App Code)                 ├─► ArgoCD Pulls Manifests
         │                                       │
         ▼                                       ▼
  GitHub Actions Runner                   K3s Cluster (ArgoCD Agent)
         │                                       │
         ├─► Builds Docker Image                 ├─► Compares Live Cluster State
         ├─► Pushes to Docker Registry           │   with Git Repository Manifests
         ├─► Updates Image Tag in GitOps         │
         ▼                                       ▼
    Docker Hub                              Reconciles State & Deploys Pods
```

### A. The Application Repository (`time-guild`)
This repository contains:
1.  **Next.js Source Code**: The core web app logic, UI components, and API routes.
2.  **Dynamic Provisioning Logic (`src/lib/k8s.ts`)**: JavaScript functions that invoke the Kubernetes REST API inside the cluster to spin up namespaces on-demand.
3.  **Local Dev Chart (`infra/helm/timeguild`)**: The generic blueprints (Helm templates) used to package and configure the application.

### B. The GitOps Repository (`time-guild-gitops`)
This repository acts as the **Single Source of Truth** for the desired state of the K3s cluster. It contains:
1.  **Environment Mappings**: Specific Helm value overrides (`values-dev.yaml`, `values-lab.yaml`, `values-prod.yaml`) for each deployment environment.
2.  **ArgoCD ApplicationSets (`infra/applicationsets/applicationset.yaml`)**: High-level controller specifications that instruct ArgoCD to automatically watch the git repository and provision environments (`dev`, `staging`, `prod`) dynamically.

---

## 2. Granular Micro Architecture (Under the Hood)

Let's trace exactly how a request is routed, processed, and reconciled at a container and network layer.

### A. DNS and Ingress Routing Flow
When a browser makes a request to `elliott.timeguild.xyz` or `fake.timeguild.xyz`:

```
                             [ DNS Resolution (Namecheap) ]
                                          │
                                          ▼
                                     [ Elastic IP ]
                                          │
                                          ▼
                           [ Traefik Ingress Controller ]
                                          │
                  ┌───────────────────────┴───────────────────────┐
                  ▼                                               ▼
     Matches exact Host rule?                        Fallback to Wildcard rule?
  Host("elliott.timeguild.xyz")                      HostRegexp("*.timeguild.xyz")
  (Priority: 10000)                                  (Priority: Default)
                  │                                               │
                  ▼                                               ▼
         [ Service: Port 80 ]                           [ Service: Port 80 ]
                  │                                               │
                  ▼                                               ▼
   [ tenant-elliott Namespace ]                    [ timeguild-dev Namespace ]
   [ Pod: Next.js (PORT=80) ]                      [ Pod: Next.js (PORT=80) ]
                  │                                               │
                  ▼                                               ▼
     Redirects to Creator Profile                     Displays Marketplace Page
```

1.  **DNS Lookup**: Namecheap matches the wildcard `*` A record and points the client to the AWS Elastic IP.
2.  **Traefik Entrypoint**: Traefik (listening on ports 80/443) receives the request header containing the target host (e.g. `elliott.timeguild.xyz`).
3.  **Ingress Evaluation & Priorities**:
    *   **The Wildcard Router**: The main dev deployment (`timeguild-dev`) has an Ingress rule matching `*.timeguild.xyz` (using Traefik's regex parser).
    *   **The Tenant Router**: The dynamically created Ingress for a registered creator has an exact match rule: `Host(elliott.timeguild.xyz)`.
    *   **Priority Resolution**: Normally, Traefik matches by rule length (preferring the longer regex rule). By adding the annotation `traefik.ingress.kubernetes.io/router.priority: "10000"` to the dynamic ingress, we force Traefik to evaluate and match the exact host first.
4.  **Route Execution**:
    *   **Registered User (`elliott.timeguild.xyz`)**: Routes to the `tenant-elliott` namespace. The tenant pod reads the `TENANT_ID=elliott` env variable and issues a `307 Temporary Redirect` to the creator profile `/creator/<uuid>`.
    *   **Fake User (`fake.timeguild.xyz`)**: No exact Ingress match exists. Traefik falls back to the wildcard rule, routing it to the parent `timeguild-dev` marketplace pod. The parent pod checks the host, detects it is not a registered tenant, and displays the public marketplace/landing page.

### B. cert-manager Wildcard SSL Flow
To make all connections secure:
1.  **ClusterIssuer**: Connects K3s to Let's Encrypt using the ACME DNS-01 challenge.
2.  **DNS-01 Challenge**: cert-manager verifies ownership of `timeguild.xyz` by writing a temporary TXT DNS record (via the Cloudflare or DNS provider API).
3.  **Certificate Secret**: Upon validation, Let's Encrypt signs a wildcard SSL certificate. cert-manager saves this certificate as `wildcard-tls-secret` inside the `kube-system` namespace.
4.  **Traefik Default Store**: A Kubernetes namespace boundary normally prevents `tenant-elliott` from mounting a secret stored in `kube-system`. We solve this by adding a `TLSStore` resource to Traefik. This registers `wildcard-tls-secret` as the global default fallback certificate.

### C. Explicit Ingress TLS vs. Traefik Default TLS Store (Macro & Micro)

#### 1. The Macro Layer (The Ingress Spec Configuration)
*   **The Problem with `tls: null`**: 
    When Helm values define `tls: null`, the generated Ingress resource in Kubernetes does **not** contain a `spec.tls` block. Technically, at the Kubernetes resource level, the Ingress is defined as HTTP-only.
*   **Why HTTPS Still Resolves**: 
    Even without `spec.tls`, Traefik intercepts incoming HTTPS requests (port 443) because its global entrypoints are configured to listen for TLS. When a request arrives, Traefik inspects its default certificate store, finds our wildcard certificate, and serves it as a fallback. 
*   **Why Explicit TLS is Better**: 
    Setting `tls: null` is bad practice because it masks the true networking requirements of the Ingress. Tools like `kubectl describe ingress` or ArgoCD will show the resource as insecure.

#### 2. The Micro Layer (The Decoupled TLS Mapping)
To achieve explicit TLS configuration without duplicating certificates across namespaces, we configure the Ingress spec with a `tls` block, but **omit** the `secretName`:

```yaml
spec:
  tls:
    - hosts:
        - timeguild.xyz
        - "*.timeguild.xyz"
  rules:
    - host: "timeguild.xyz"
      http: ...
```

*   **Traefik TLS Matcher**: 
    When Traefik reads this Ingress resource, the presence of `spec.tls` instructs it to configure a TLS-terminated route specifically for `timeguild.xyz` and `*.timeguild.xyz`.
*   **Default TLS Store Fallback**: 
    Because `secretName` is omitted, Traefik does not attempt to look up a local secret in the namespace. Instead, it falls back to the Traefik `default` `TLSStore` (located in `kube-system`), serving the pre-authenticated wildcard SSL certificate.
*   **Namespace Security Bypass**: 
    This allows us to enforce strict TLS configuration across all environments (`dev`, `lab`, `prod`) while ensuring that private keys are never exposed or copied into user namespaces.

---

## 3. The ArgoCD Reconcile Loop & The Secrets Conflict

Understanding how GitOps manages state is critical to preventing live environment config overrides.

```
       [ Git Repository ]
         (Desired State)
                │
                ▼
          [ ArgoCD ]  ◄─── Runs Reconcile Loop
                │
        ┌───────┴───────┐
        ▼               ▼
  (ConfigMatch)   (OutOfSync)
        │               │
        ▼               ▼
    Do Nothing     Apply Manifests
                        │
                        ▼
                [ K3s Cluster ]
                 (Live State)
```

### A. The Self-Heal Loop
1.  ArgoCD constantly compares the **desired state** (Git commits) with the **live state** (Kubernetes resources).
2.  If a developer manually edits a resource in K3s (e.g. updating a secret via `kubectl patch`), ArgoCD marks the application as `OutOfSync`.
3.  Because `selfHeal: true` is enabled, ArgoCD immediately applies the manifest defined in Git, **overwriting** the manual changes.

### B. How We Solved the Secret Overwrite Loop
*   **The Problem**: The Stripe API keys were originally defined inside the Helm template `secrets.yaml`. When the build system updated the image tag in values, ArgoCD triggered a sync and applied `secrets.yaml`, replacing the live credentials in K3s with git placeholders (`sk_test_placeholder`).
*   **The Fix**:
    1.  We deleted `secrets.yaml` from the Helm chart. ArgoCD no longer has any knowledge of this secret.
    2.  We modified the Deployment template to bind environment variables to `timeguild-dev-env-secrets`.
    3.  We run a script (`apply-env-secrets.sh`) that reads local `.env` files and creates/updates `timeguild-dev-env-secrets` directly in K3s using `kubectl create secret --dry-run=client -o yaml | kubectl apply -f -`.
    4.  Since `timeguild-dev-env-secrets` is not tracked in the Git repository, ArgoCD **never** touches or deletes it during synchronization!

---

## 4. The Dynamic Tenant Provisioning Flow (Step-by-Step)

When a user registers or updates their role to `creator` in the UI:

```
[ User UI ] ──► POST /api/creators ──► [ Next.js API Route ]
                                                │
                                                ├─► Update SQLite DB (scoping)
                                                ├─► Read In-Cluster Token
                                                ▼
                                    [ K3s API Server ] (fetch POST)
                                                │
        ┌───────────────────────┬───────────────┴───────┬───────────────────────┐
        ▼                       ▼                       ▼                       ▼
[ Namespace: tenant-x ]   [ Deployment ]            [ Service ]             [ Ingress ]
                          - Pulls image tag         - Exposes Port 80       - Host: x.timeguild.xyz
                          - Copies secrets env                               - Priority: 10000
```

1.  **Database Scoping**: The Next.js API route updates the `users` and `tenants` tables, matching the creator's username to their namespace identifier.
2.  **In-Cluster Token**: Next.js reads the JSON Web Token auto-mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
3.  **Kubernetes API Calls**: Next.js sends direct HTTP POST requests to `https://kubernetes.default.svc` to create:
    *   **Namespace**: `tenant-${username}`.
    *   **Deployment**: Runs the app image, injecting `TENANT_ID=${username}`, `PORT=80`, and copying database paths and decoupled secrets (`STRIPE_SECRET_KEY`, etc.) from the parent pod's environment.
    *   **Service**: Exposes port `80` targeting the Next.js process inside the pod.
    *   **Ingress**: Maps `username.timeguild.xyz` to the service, setting `ingressClassName: "traefik"` and the router priority annotation (`10000`).
