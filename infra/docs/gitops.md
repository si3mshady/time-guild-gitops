# GitOps Workflow & Promotion Guide

This document describes the GitOps workflow, repository layout, and environment promotion tree for the **Time Guild / AURA** platform using ArgoCD.

---

## GitOps Architecture

```text
Promotion Tree:
[Dev Commit] ──> [Auto Build & Test] ──> [Push Dev Tag] ──> [Auto Sync Dev App]
                                                                   │
                                                         (Create GitOps PR)
                                                                   │
                                                                   ▼
[Merge GitOps PR] ──> [Staging Sync] ──> [Manual Sync Production Approval]
```

---

## 1. Repository Layout Split
We structure the platform into two decoupled git repositories:
1. **Application Repository (`time-guild`)**: Contains Next.js source code, Dockerfiles, and CI pipelines (GitHub Actions workflows).
2. **GitOps Manifest Repository (`time-guild-gitops`)**: Contains Kubernetes Helm charts, environment value overrides (`values-dev.yaml`, `values-lab.yaml`, `values-prod.yaml`), and ArgoCD Application manifests.

---

## 2. Sync Waves Deployment Order
ArgoCD uses **Sync Waves** to coordinate resource creation. Lower waves deploy first. If a wave fails, ArgoCD stops the deployment.

```
┌──────────────────────────────────────┐
│ Wave -5: Namespaces, Secrets (ESO)   │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ Wave -2: Redis, Postgres StatefulSet │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ Wave 0: PreSync Migration Job        │  ◄── DB schema upgrade runs here
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ Wave 5: Next.js Server Pods, Ingress │  ◄── Application traffic routed
└──────────────────────────────────────┘
```

*   **Sync Wave -5 (Infra Foundations)**:
    - Files: `namespace.yaml`, `secrets.yaml` (External Secrets Operator targets), `configmap.yaml`.
    - Reason: Ensures environment properties and security contexts exist before pods launch.
*   **Sync Wave -2 (Stateful Services)**:
    - Files: `postgres-statefulset.yaml`, `redis-deployment.yaml`.
    - Reason: Deploys state engines and memory queues.
*   **Sync Wave 0 (PreSync Database Hook)**:
    - Files: `db-migration-job.yaml` (Annotated with `argocd.argoproj.io/hook: PreSync`).
    - Reason: Runs database schema updates (migrating SQL tables) so that Next.js pods connect only to a fully-configured database, preventing runtime crashes.
*   **Sync Wave 5 (Stateless Services & Ingress)**:
    - Files: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `hpa.yaml`.
    - Reason: Deploys the main web pods, exposes them via services, configures scaling limits, and opens public ingress routing only when all backend resources are running.

---

## 3. Environment Promotion Lifecycle

### Step A: Code Commits (Development)
*   A developer pushes code changes to the application repository.
*   CI pipelines execute linting, TypeScript compiling, and tests.
*   On success, the pipeline compiles a new Docker container, tags it with the Git commit SHA (e.g. `si3mshady/time-guild:sha-a1b2c3d`), and pushes it to the registry.

### Step B: Staging Promotion
*   To promote the version to Staging/Lab, update the image tag value in the GitOps repository's `values-lab.yaml` file:
    ```yaml
    image:
      tag: "sha-a1b2c3d"
    ```
*   Push the change to the GitOps master branch.
*   ArgoCD detects the commit and triggers a sync, updating the staging cluster.

### Step C: Production Promotion (Manual Gate)
*   To promote to production, create a Pull Request on the GitOps repository merging `staging` changes into the `main` branch.
*   Once merged, ArgoCD detects that the production application (`timeguild-prod`) is `OutOfSync`.
*   An administrator must review the changes and click **Sync** in the ArgoCD UI or via the CLI to trigger the rollout, ensuring a manual verification gate.
