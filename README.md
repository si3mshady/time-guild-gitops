# time-guild-gitops

This is the GitOps and infrastructure configuration repository for the **Time Guild** platform.

## Repository Structure
- **`infra/helm/timeguild`**: The Helm chart templates and value files for deploying the application.
- **`infra/argocd`**: ArgoCD Application declarations that synchronize target states from Git into the K3s cluster.
- **`infra/applicationsets`**: ApplicationSets that orchestrate multi-environment deployments (`dev`, `staging`, `prod`) dynamically.
- **`infra/kubernetes`**: Core Kubernetes resources including cert-manager ClusterIssuers, Wildcard Certificates, and Traefik stores.
