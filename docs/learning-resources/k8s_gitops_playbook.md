# Kubernetes GitOps & Auto-Provisioning Playbook

This playbook provides the exact configuration manifests, code snippets, and terminal commands needed to execute Days 3 through 7 of the GitOps roadmap on your AWS EC2 instance running K3s.

---

## Day 3 Playbook — Host Access & DNS Verification

Now that K3s is installed on your EC2 instance, you need to configure external access and map your Namecheap domain.

### 1. Configure AWS Security Groups
Make sure your EC2 instance's security group has the following inbound rules:
*   **Port 80 (HTTP)**: Open to `0.0.0.0/0` (public access).
*   **Port 443 (HTTPS)**: Open to `0.0.0.0/0` (public access).
*   **Port 6443 (Kubernetes API)**: Open **strictly** to your local home IP address (e.g. `203.0.113.5/32`) to prevent security scans and unauthorized control of your cluster.

### 2. Configure Namecheap Wildcard DNS
In your Namecheap Advanced DNS panel:
1.  Add an **A Record**:
    *   Host: `@`
    *   Value: `YOUR_AWS_ELASTIC_IP`
    *   TTL: Automatic (or 1 min for testing)
2.  Add a **Wildcard A Record**:
    *   Host: `*`
    *   Value: `YOUR_AWS_ELASTIC_IP`
    *   TTL: Automatic

### 3. Setup Local Kubectl Access
To manage the cluster from your local computer:
1.  SSH into your EC2 instance and read the kubeconfig file:
    ```bash
    sudo cat /etc/rancher/k3s/k3s.yaml
    ```
2.  Copy the output, create a file locally at `~/.kube/config`, and paste the content.
3.  In your local `~/.kube/config`, find the line:
    ```yaml
    server: https://127.0.0.1:6443
    ```
    Change `127.0.0.1` to your public **AWS Elastic IP**:
    ```yaml
    server: https://YOUR_AWS_ELASTIC_IP:6443
    ```
4.  Test access from your local terminal:
    ```bash
    kubectl get nodes
    ```

---

## Day 4 Playbook — Helm & ArgoCD GitOps

We deploy ArgoCD and configure the GitOps pipeline to track your application repository.

### 1. Install ArgoCD
Run these commands from your local machine (connected to K3s):
```bash
# Create namespace
kubectl create namespace argocd

# Apply official installation manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Retrieve ArgoCD Admin Password
Once the pods are running, extract the auto-generated admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. Expose ArgoCD UI
To access the dashboard without public exposure, use port-forwarding:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Now, open `https://localhost:8080` in your browser (Username: `admin`, Password: the decrypted string from step 2).

### 4. Create the ArgoCD Application Manifest
Create the following file in your repository at `infra/argocd/timeguild-app.yaml` to register your project Helm chart:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: timeguild-core
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/YOUR_GITHUB_USER/time-guild.git'
    targetRevision: HEAD
    path: infra/helm/timeguild
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Day 5 Playbook — cert-manager & Wildcard SSL

We secure all subdomains (`*.yourdomain.com`) using cert-manager, Cloudflare nameserver delegation, and Traefik's Default TLS Store.

### 1. Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

### 2. Cloudflare DNS-01 API Secret
Once nameservers are pointed from Namecheap to Cloudflare, generate a Cloudflare API Token (Zone:Edit, DNS:Edit permissions) and apply it as a secret in K3s:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: kube-system
type: Opaque
stringData:
  api-token: YOUR_CLOUDFLARE_API_TOKEN
```

### 3. Deploy Let's Encrypt ClusterIssuer
Create and apply `infra/kubernetes/clusterissuer.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-wildcard-issuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-wildcard-private-key
    solvers:
      - dns01:
          cloudflare:
            email: your-email@yourdomain.com
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

### 4. Request Wildcard SSL Certificate
Create and apply `infra/kubernetes/wildcard-certificate.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-tls-cert
  namespace: kube-system
spec:
  secretName: wildcard-tls-secret
  issuerRef:
    name: letsencrypt-wildcard-issuer
    kind: ClusterIssuer
  dnsNames:
    - "yourdomain.com"
    - "*.yourdomain.com"
```
Verify the certificate status:
```bash
kubectl get certificate -n kube-system
```

### 5. Configure Traefik Default TLS Store
Create and apply `infra/kubernetes/traefik-tlsstore.yaml`:

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: TLSStore
metadata:
  name: default
  namespace: kube-system
spec:
  defaultCertificate:
    secretName: wildcard-tls-secret
```
Now, any Ingress created in K3s on your domain automatically gets HTTPS without copying secrets!

---

## Day 6 Playbook — Dynamic In-Cluster Provisioning API

Here is the exact implementation to spawn namespaces when a user signs up.

### 1. RBAC Manifests for Next.js App
We must allow the Next.js pod to manage Kubernetes namespaces. Add this to your Helm templates:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nextjs-k8s-provisioner
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-manager-role
rules:
  - apiGroups: [""]
    resources: ["namespaces", "services", "pods"]
    verbs: ["create", "get", "list", "watch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["create", "get", "list", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["create", "get", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: nextjs-k8s-provisioner-binding
subjects:
  - kind: ServiceAccount
    name: nextjs-k8s-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: namespace-manager-role
  apiGroup: rbac.authorization.k8s.io
```

### 2. Next.js Kubernetes Client Helper
Create the file `src/lib/k8s.ts` inside your codebase. This file uses the in-cluster service account token to run API requests:

```typescript
import fs from "fs";
import https from "https";

const K8S_HOST = "https://kubernetes.default.svc";
const TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token";
const CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";

function getK8sConfig() {
  const token = fs.readFileSync(TOKEN_PATH, "utf-8").trim();
  const ca = fs.readFileSync(CA_PATH);
  const agent = new https.Agent({ ca });
  return {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    agent,
  };
}

export async function provisionTenantNamespace(username: string, domain: string) {
  const { headers, agent } = getK8sConfig();
  const ns = `tenant-${username}`;

  // 1. Create Namespace
  await fetch(`${K8S_HOST}/api/v1/namespaces`, {
    method: "POST",
    headers,
    agent,
    body: JSON.stringify({
      apiVersion: "v1",
      kind: "Namespace",
      metadata: { name: ns, labels: { type: "tenant", tenant: username } },
    }),
  });

  // 2. Create Deployment
  await fetch(`${K8S_HOST}/apis/apps/v1/namespaces/${ns}/deployments`, {
    method: "POST",
    headers,
    agent,
    body: JSON.stringify({
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: { name: "timeguild-app" },
      spec: {
        replicas: 1,
        selector: { matchLabels: { app: "timeguild" } },
        template: {
          metadata: { labels: { app: "timeguild" } },
          spec: {
            containers: [
              {
                name: "web",
                image: "YOUR_DOCKERHUB_USERNAME/time-guild:latest",
                ports: [{ containerPort: 3000 }],
                env: [
                  { name: "TENANT_ID", value: username },
                  { name: "DATABASE_URL", value: process.env.DATABASE_URL } // Connect to PostgreSQL
                ]
              }
            ]
          }
        }
      }
    }),
  });

  // 3. Create Service
  await fetch(`${K8S_HOST}/api/v1/namespaces/${ns}/services`, {
    method: "POST",
    headers,
    agent,
    body: JSON.stringify({
      apiVersion: "v1",
      kind: "Service",
      metadata: { name: "timeguild-service" },
      spec: {
        selector: { app: "timeguild" },
        ports: [{ protocol: "TCP", port: 80, targetPort: 3000 }]
      }
    }),
  });

  // 4. Create Ingress
  await fetch(`${K8S_HOST}/apis/networking.k8s.io/v1/namespaces/${ns}/ingresses`, {
    method: "POST",
    headers,
    agent,
    body: JSON.stringify({
      apiVersion: "networking.k8s.io/v1",
      kind: "Ingress",
      metadata: {
        name: "timeguild-ingress",
        annotations: {
          "kubernetes.io/ingress.class": "traefik",
          "traefik.ingress.kubernetes.io/router.entrypoints": "websecure"
        }
      },
      spec: {
        rules: [
          {
            host: `${username}.${domain}`,
            http: {
              paths: [
                {
                  path: "/",
                  pathType: "Prefix",
                  backend: {
                    service: { name: "timeguild-service", port: { number: 80 } }
                  }
                }
              ]
            }
          }
        ]
      }
    }),
  });
}
```

---

## Day 7 Playbook — Observability Autodiscovery

We configure Promtail and Prometheus to dynamically scrape the newly provisioned namespaces.

### 1. Promtail Autodiscovery Config
Update your Promtail Helm values or YAML config to extract namespace and pod labels dynamically:

```yaml
config:
  snippets:
    extraScrapeConfigs: |
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_namespace]
            regex: tenant-(.*)
            action: keep
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: app
          - source_labels: [__meta_kubernetes_namespace]
            regex: tenant-(.*)
            replacement: $1
            target_label: tenant
```

### 2. Prometheus ServiceMonitor
Create and apply `infra/kubernetes/servicemonitor.yaml` to dynamically scrape `/api/metrics` from any pod labeled `app: timeguild` inside tenant namespaces:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: timeguild-monitor
  namespace: default
spec:
  selector:
    matchLabels:
      app: timeguild
  namespaceSelector:
    any: true
  endpoints:
    - port: web
      path: /api/metrics
      interval: 15s
```
