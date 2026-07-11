# Infrastructure Directory Structure

This document details the purpose of each file and folder in the `infra/` folder.

---

## Folder Hierarchy & Descriptions

```text
infra/
├── docker/                 # Container definition manifests
│   ├── Dockerfile.prod     # Optimized production build (multi-stage)
│   ├── Dockerfile.dev      # Development build wrapper
│   └── .dockerignore       # Build context file exclusions
├── compose/                # Local runtime containers configurations
│   └── docker-compose.yaml # NextJS, Postgres, and Redis dev stack
├── kubernetes/             # Standalone raw manifest declarations
│   ├── namespaces.yaml     # Dev/Staging/Production isolated namespaces
│   ├── configmap.yaml      # Non-sensitive settings mappings
│   ├── secrets.yaml        # Encryption base64 config templates
│   ├── pvc.yaml            # Storage claim allocations (SQLite persist)
│   ├── deployment.yaml     # Runtime Pod, resources, and probe bindings
│   ├── service.yaml        # Internal networking ClusterIP mappings
│   ├── ingress.yaml        # Wildcard domain routing configurations
│   ├── hpa.yaml            # CPU/Memory resource-limit auto-scaling
│   ├── networkpolicy.yaml  # Namespace network isolation configurations
│   └── serviceaccount.yaml # Non-privileged service token configurations
├── helm/                   # Parameterized application deployments
│   └── timeguild/          # Root Chart definition
│       ├── Chart.yaml      # Package version metadata descriptors
│       ├── values.yaml     # Base deployment configuration values
│       ├── values-dev.yaml # Lightweight developer profile values
│       ├── values-lab.yaml # Target k3s home-lab environment values
│       ├── values-prod.yaml# Production-scale high-availability values
│       └── templates/      # Dynamic YAML layouts (Deployment, Ingress, etc.)
├── argocd/                 # GitOps application definitions
│   ├── application-dev.yaml # ArgoCD App for Dev namespaces
│   ├── application-staging.yaml # ArgoCD App for Staging/Lab namespaces
│   ├── application-prod.yaml # ArgoCD App for Production namespaces
│   └── app-of-apps.yaml    # Root supervisor App-of-Apps parent config
├── applicationsets/        # Multi-environment generators templates
│   └── applicationset.yaml # Auto-synchronization lists configurations
├── monitoring/             # Cluster observability configurations
│   └── prometheus-servicemonitor.yaml # Prometheus targets configuration
├── logging/                # Cluster aggregate logging details
│   └── logging_setup.md    # Grafana Loki and Promtail installation guide
├── scripts/                # Platform management tools
│   ├── build.sh            # Production container build compiler
│   ├── push.sh             # Registry update shipper
│   ├── deploy.sh           # Helm environment installer
│   ├── restart.sh          # Cluster deployment rollout trigger
│   ├── rollback.sh         # Helm deployment rollback tool
│   ├── cleanup.sh          # Helm deployment purge tool
│   └── dev-local.sh        # Docker Compose dev engine manager
└── docs/                   # Guides and platform runbooks
    ├── structure.md        # [This File] Directory map description
    ├── architecture.md     # Platform infrastructure design blueprint
    ├── deployment.md       # Cluster bootstrap deployment guide
    ├── gitops.md           # Continuous Delivery promotion guide
    ├── operations.md       # Back-office admin runtime runbook
    └── troubleshooting.md  # Incident response and diagnostic manuals
```
