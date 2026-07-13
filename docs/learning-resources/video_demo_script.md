# Video Demo Guide: Dynamic K8s Tenant Provisioning & Custom Routing

This guide outlines a highly polished, 2-3 minute video demonstration script to showcase today's Cloud-Native accomplishments to hiring managers, technical leads, or your developer network on LinkedIn.

---

## 1. Preparation & Setup (Screen Layout)

For maximum impact, use a **split-screen layout**:
*   **Left Half**: Web Browser (Chrome/Firefox) opened to `http://localhost:3000` (or `timeguild.xyz` main portal) and a second tab ready for your Stripe Test Dashboard.
*   **Right Half**: Terminal running a live-watch command to show resources spinning up in real-time:
    ```bash
    watch -n 0.5 "kubectl get ns | grep tenant && echo '---' && kubectl get pods,services,ingress -n tenant-elliott 2>/dev/null"
    ```

---

## 2. Step-by-Step Demo Flow

| Time | Visual (What you show) | Narration / Talking Points (What you say) |
| :--- | :--- | :--- |
| **0:00 - 0:30** | **Left**: Main Time Guild Portal.<br>**Right**: Live terminal (no tenant namespaces running). | "I want to show you how we built a **real-time, sub-second Kubernetes tenant provisioning engine** for a multi-tenant SaaS application. We leverage an in-cluster REST client to spin up isolated container runtimes, services, and ingress routes on the fly when a creator signs up, avoiding GitOps pipeline latency." |
| **0:30 - 1:00** | **Left**: Register a creator profile (e.g., username `elliott`). Click "Save".<br>**Right**: Watch namespace `tenant-elliott` and the deployment/pods/ingress spin up instantly (in ~2 seconds). | "Watch the terminal on the right. As I click register, Next.js queries the K3s API server directly, creating a dedicated `tenant-elliott` namespace, deploying their Next.js container, mapping a cluster service, and configuring an ingress. Everything runs inside isolated boundaries in less than 3 seconds." |
| **1:00 - 1:30** | **Left**: Open a new tab and navigate to `http://elliott.timeguild.xyz`. Show the browser redirecting to `/creator/49def329-...` over HTTPS (click the padlock to show the wildcard TLS certificate). | "Because we configured wildcard A records on Namecheap (routing `*.timeguild.xyz` to our AWS Elastic IP) and cert-manager with DNS-01 challenges, the new subdomain is live instantly. Traefik's Default TLS Store automatically serves our wildcard SSL certificate. Note the secure HTTPS connection." |
| **1:30 - 2:00** | **Left**: Navigate to `fake.timeguild.xyz` (shows main marketplace). Show terminal details of Ingress priority annotation `10000`. | "If we go to `fake.timeguild.xyz`, Traefik falls back to our wildcard ingress and displays the marketplace. For registered subdomains, we use a Traefik router priority annotation of `10000` to prevent the wildcard route from hijacking tenant traffic." |
| **2:00 - 2:30** | **Right**: Run `kubectl describe pod -n tenant-elliott` to show the active `STRIPE_SECRET_KEY` env var. | "Finally, to prevent GitOps tools like ArgoCD from overwriting our live Stripe secrets back to chart placeholder defaults during self-heal cycles, we decoupled secrets from Helm. We inject them dynamically into unmanaged secrets via helper scripts. The tenant container now correctly inherits the real Stripe Test API key." |

---

## 3. High-Value Technical Keyword Guide

Sprinkle these concepts throughout your video or LinkedIn caption to emphasize the complexity of what was resolved:

1.  **Direct In-Cluster API Integration**: *"We bypassed GitOps pull latency (which takes 2-3 minutes) to achieve sub-second onboarding by communicating directly with K3s from Next.js using custom RBAC bindings."*
2.  **GitOps & Secret Decoupling**: *"ArgoCD's self-healing loop usually reverts in-cluster secret overrides to match the Git repository state. We solved this by decoupling the secrets template from Helm and mapping to unmanaged secrets."*
3.  **Traefik Router Priority Annotation**: *"Traefik normally prioritizes regex rules over exact rules because they are longer in string length. We corrected wildcard route hijacking by injecting a custom priority priority key (`10000`)."*
4.  **ACME DNS-01 & Default TLS Store**: *"To avoid hitting Let's Encrypt rate limits, we issued a wildcard cert via DNS-01 challenges and loaded it into Traefik's Default TLS Store, securing thousands of dynamic namespaces without secret duplication."*
