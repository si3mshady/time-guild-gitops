# Day 5: cert-manager Wildcard SSL & Traefik Default TLS Store

> [!NOTE]
> **Status: COMPLETED**

---

## 1. Architectural Rationale: Why We Do This

*   **cert-manager**: Manages the complete lifecycle of TLS certificates in your Kubernetes cluster, including requesting, validating, and renewing them automatically before they expire.
*   **Let's Encrypt Rate Limits (ACME DNS-01)**: If you request a separate SSL certificate for every single customer subdomain (`marcus.yourdomain.com`, `avery.yourdomain.com`), you will hit Let's Encrypt's strict limit of **50 unique certificates per domain per week**. When you scale, new creators will get browser security warnings because you cannot issue more certificates.
*   **Wildcard Certificate Solution**: We resolve this by generating a single wildcard certificate (`*.yourdomain.com`). This requires a **DNS-01 ACME challenge** (Let's Encrypt writes a temporary TXT record to your DNS zone via API to prove you own the domain). This is why zone delegation to Cloudflare is used—Cloudflare's API is fast, secure, and natively supported by cert-manager.
*   **Traefik Default TLS Store**: Normally, Kubernetes namespace boundaries prevent pods/Ingresses in `tenant-marcus` from reading secrets (like the SSL certificate) stored in another namespace. Instead of duplicating the wildcard secret across thousands of namespaces (which is a security and performance risk), we load it into Traefik's **Default TLS Store**. Any Ingress in the cluster that omits a TLS secret will automatically be served with this default wildcard certificate.

---

## 2. Core Tasks

### A. Install cert-manager
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
```

### B. Cloudflare Nameserver Delegation & Secrets
1.  Delegate your Namecheap domain nameservers to **Cloudflare** (Free tier).
2.  Generate a Cloudflare API Token (Zone:Edit, DNS:Edit permissions) and save it in your cluster:
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

### C. Create ClusterIssuer & Wildcard Certificate
Apply the ACME DNS-01 Issuer and Certificate configuration to request `*.yourdomain.com`:
*   Use `infra/kubernetes/clusterissuer.yaml` to authenticate with Let's Encrypt.
*   Use `infra/kubernetes/wildcard-certificate.yaml` to request the wildcard cert and store it in `kube-system/wildcard-tls-secret`.

### D. Setup Traefik default TLS Store
Apply the Traefik `TLSStore` resource to establish a default wildcard SSL:
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

---

## 3. Study & Reference Materials
*   **cert-manager DNS-01 ACME Validation**: Learn why DNS challenge validation is required to issue wildcard certificates:  
    [https://cert-manager.io/docs/configuration/acme/dns01/](https://cert-manager.io/docs/configuration/acme/dns01/)
*   **Traefik TLSStore Reference**: Study how Traefik handles default certificates for non-configured TLS requests:  
    [https://doc.traefik.io/traefik/https/tls/#default-certificate](https://doc.traefik.io/traefik/https/tls/#default-certificate)
*   **Let's Encrypt Rate Limits (ACME DNS-01)**: Learn the constraints and boundaries of free certificate issuance:  
    [https://letsencrypt.org/docs/rate-limits/](https://letsencrypt.org/docs/rate-limits/)

---

## 4. Real-World Lab Implementation Notes & Namecheap Config

### A. Namecheap Wildcard DNS Configuration
To route all dynamic subdomains (`*.timeguild.xyz`) to our K3s cluster on AWS:
1.  **Main Record**: Created an A record with Host `@` pointing to the cluster's **Elastic IP** (TTL: `1 minute` / `Auto`).
2.  **Wildcard Record**: Created a second A record with Host `*` (wildcard) pointing to the same **Elastic IP** (TTL: `1 minute`). This ensures that any arbitrary subdomain request (e.g. `elliott.timeguild.xyz` or `fake.timeguild.xyz`) gets routed immediately to our Traefik entrypoint.

### B. cert-manager Certificate Extension
To secure our live wildcard subdomains over HTTPS:
1.  Modified [wildcard-certificate.yaml](file:///home/si3mshady/time-guild/infra/kubernetes/wildcard-certificate.yaml) to include the new production domains:
    ```yaml
    dnsNames:
      - "*.timeguild.xyz"
      - "timeguild.xyz"
    ```
2.  Applied to K3s. cert-manager verified ownership and successfully updated the `wildcard-tls-secret` in `kube-system`. Traefik immediately loaded the updated certificate to handle secure TLS handshakes for `*.timeguild.xyz` subdomains.

### C. Explicit Ingress TLS vs. Traefik Default TLS Store
*   **The Ingress Spec Difference**:
    When an Ingress is created with `tls: null` in Helm, the resulting Kubernetes manifest lacks the `spec.tls` block entirely. 
*   **How HTTPS Still Resolved (Implicitly)**:
    Even without `spec.tls` on the Ingress, Traefik intercepted HTTPS requests (port 443) and decrypted them using the default wildcard cert because it was loaded into the default `TLSStore` in `kube-system`.
*   **The Explicit Fix**:
    We modified our environment values (`values-dev.yaml`, `values-lab.yaml`) to explicitly define `spec.tls` but **omitted** the `secretName`:
    ```yaml
    ingress:
      tls:
        - hosts:
            - timeguild.xyz
            - "*.timeguild.xyz"
    ```
    This signals to Kubernetes that the ingress endpoints require TLS, while telling Traefik to safely fall back to the pre-authenticated default wildcard certificate in `kube-system` rather than expecting a duplicated secret in the tenant namespace.
