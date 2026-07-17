# Day 4: Helm Chart & ArgoCD Multi-Repo GitOps

> [!NOTE]
> **Status: COMPLETED**

---

## 1. Architectural Rationale: Why We Do This

*   **Multi-Repo GitOps**: Separating your code (`time-guild`) from your cluster deployment configurations (`time-guild-gitops`) is a core security boundary. Developers pushing code do not need direct access to modify the production cluster state. Additionally, this isolation prevents circular dependency loops in automated pipelines.
*   **ArgoCD (GitOps Engine)**: Traditional deployments rely on imperative commands (`kubectl apply` or script runners). GitOps is *declarative*: you define your target cluster state in Git, and ArgoCD continuously monitors and reconciles the live cluster. If someone manually deletes a pod or makes an unauthorized change in the cluster, ArgoCD automatically detects the drift and reverts it back to matches Git. If your cluster crashes, you can redeploy the entire system in minutes simply by pointing ArgoCD to your GitOps repository.
*   **Helm Charts**: Managing plain Kubernetes YAMLs for multiple environments (dev, staging, production) leads to duplicate files and configuration errors. Helm allows us to write parameterized templates once and inject distinct values (e.g. replica count, image tag, domain) for each environment.

---

## 2. Core Tasks

### A. The Multi-Repo GitOps Pattern
Your architecture is configured with the standard industry-grade split:
1.  **Code Repository (`time-guild`)**: Contains your application code, Dockerfile, and CI/CD pipelines.
2.  **GitOps Repository (`time-guild-gitops`)**: Contains the Helm chart values, environments, and ArgoCD manifests.

ArgoCD is configured to watch `https://github.com/si3mshady/time-guild-gitops.git`. 

### B. Image Promotion Pipeline (CI/CD update)
To enable automated deployments when you commit code to `time-guild`:
1.  Our GitHub Actions CI/CD pipeline builds and pushes the image (e.g. `si3mshady/time-guild:sha-xxxx`) to Docker Hub.
2.  The pipeline must then clone the `time-guild-gitops` repository (using a GitHub PAT secret).
3.  The pipeline writes the new tag (`sha-xxxx`) to the `image.tag` key inside `infra/helm/timeguild/values.yaml` (or `values-dev.yaml`).
4.  The pipeline commits and pushes the change back to `time-guild-gitops`.
5.  **ArgoCD** detects the change in the GitOps repo and applies the new container to K3s.

### C. Verify the Pre-configured ApplicationSet
Your repository already has a root parent config:
*   **[app-of-apps.yaml](file:///home/si3mshady/time-guild/infra/argocd/app-of-apps.yaml)**: Watches the GitOps repo folder `infra/argocd` to spin up environments.
*   **[applicationset.yaml](file:///home/si3mshady/time-guild/infra/applicationsets/applicationset.yaml)**: Uses a List generator to dynamically manage the `timeguild-dev`, `timeguild-staging`, and `timeguild-prod` environments in separate namespaces automatically.

Verify that your K3s cluster has the ApplicationSet active:
```bash
kubectl get applicationsets -n argocd
```

---

## 3. Study & Reference Materials
*   **ArgoCD ApplicationSets (List Generator)**: Learn how a single template stamps out dev, staging, and prod namespaces dynamically:  
    [https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
*   **Multi-Repo GitOps Best Practices**: Learn why separating application code from environment state is the industry standard for security and pipeline safety:  
    [https://www.weave.works/blog/why-is-a-one-git-repo-per-env-gitops-pattern-best-practice](https://www.weave.works/blog/why-is-a-one-git-repo-per-env-gitops-pattern-best-practice)
