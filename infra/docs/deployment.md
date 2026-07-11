# Deployment Guide (k3s Home Lab)

This guide walks you through building, configuring, and deploying the **Time Guild / AURA** application into a **k3s Kubernetes lab** using Helm.

---

## Prerequisites
Ensure your local machine and k3s node have the following installed:
- **k3s** (running and accessible via `kubectl`)
- **Helm v3**
- **Docker** or **Rancher Desktop** (for container compilation)
- **Local DNS utility** (e.g. `dnsmasq` or manual `/etc/hosts` access)

---

## Step 1: Build and Push the Container Image
First, build the production image using our optimized Dockerfile. By default, the build script tags it for GHCR, but you can target your local registry (e.g. k3s registry at `localhost:5000` or DockerHub):

```bash
# Make helper scripts executable
chmod +x infra/scripts/*.sh

# Compile the Docker container
# Usage: ./infra/scripts/build.sh <registry> <image-name> <tag>
./infra/scripts/build.sh my-registry.local si3mshady/time-guild 1.0.0

# Push to your registry
./infra/scripts/push.sh my-registry.local si3mshady/time-guild 1.0.0
```

---

## Step 2: Configure Secrets
Before deploying, edit the Helm secrets configuration or create a values file (`values-secrets.yaml`) containing your credentials. Do not commit your real secrets to Git.

Generate base64 strings for your secrets:
```bash
echo -n "my-jwt-secret-key" | base64
echo -n "sk_test_..." | base64
```

Create a local `secrets.yaml` template file in the cluster manually, or populate the `secrets` section in your Helm configuration.

---

## Step 3: Deploy using Helm
Using the deploy helper script, install the chart using the `lab` environment values:

```bash
# Deploy to the 'timeguild-prod' namespace using values-lab.yaml
# Usage: ./infra/scripts/deploy.sh <env> <namespace>
./infra/scripts/deploy.sh lab timeguild-prod
```

### Manual Helm command alternative:
```bash
helm upgrade --install timeguild ./infra/helm/timeguild \
  --namespace timeguild-prod \
  --create-namespace \
  -f ./infra/helm/timeguild/values.yaml \
  -f ./infra/helm/timeguild/values-lab.yaml \
  --set image.repository=my-registry.local/si3mshady/time-guild \
  --set image.tag=1.0.0
```

---

## Step 4: Configure Local DNS (Hosts File)
Because the application routes tenants based on subdomains, map the domain paths to your k3s node IP (e.g., `192.168.1.100`):

Edit your local `/etc/hosts` file (or C:\Windows\System32\drivers\etc\hosts on Windows):
```text
# Time Guild Local Lab Domain Mappings
192.168.1.100  timeguild.lab
192.168.1.100  avery.timeguild.lab
192.168.1.100  sarah.timeguild.lab
192.168.1.100  marcus.timeguild.lab
```

*For wildcards*: Standard hosts files do not support wildcard entries like `*.timeguild.lab`. For dynamic matching, configure a local **dnsmasq** instance:
```text
address=/.timeguild.lab/192.168.1.100
```

---

## Step 5: Verification
1. Verify that all pods are running and the PVC has bound:
   ```bash
   kubectl get pods -n timeguild-prod
   kubectl get pvc -n timeguild-prod
   ```
2. Verify Ingress routing:
   ```bash
   kubectl get ingress -n timeguild-prod
   ```
3. Open a browser and navigate to `http://timeguild.lab`. You should see the marketplace dashboard.
4. Try to navigate to `http://avery.timeguild.lab` to test multi-tenant subdomain loading.
