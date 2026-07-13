# Subdomain Routing & Tenant AI Architecture

This document clarifies how subdomains, logging in, and the AI scheduling assistants are routed and accessed in the Time Guild platform.

---

## 1. Platform Domain vs. Creator Subdomains

There is a clear separation between how **Creators manage their dashboard** and how **Clients access a Creator's scheduling AI**:

### A. The Platform Dashboard (Creator Login)
*   **Where it runs**: On the main platform domain: `https://yourdomain.com/auth` and `https://yourdomain.com/dashboard`.
*   **What happens when a creator logs in**:
    1.  The creator registers with their unique username (e.g. `marcus`).
    2.  They log in to access their **My Creator Dashboard** tab.
    3.  Here, they configure their availability slots, pricing, and their AI assistant's screening prompt.
    4.  The dashboard displays their unique booking link: `https://marcus.yourdomain.com`.

### B. The Scheduling AI Profile (Client Access)
*   **Where it runs**: On the creator's dedicated subdomain: `https://marcus.yourdomain.com`.
*   **How clients access it**:
    *   Clients do **not** need to log into the main platform.
    *   They visit `https://marcus.yourdomain.com` directly.
    *   They are presented with Marcus's profile page and his custom AI scheduling assistant (which screens them via text chat before allowing them to book a slot).

---

## 2. Under the Hood: Kubernetes Routing

When you transition to K3s on your AWS EC2 instance, the routing operates on a hybrid model that keeps resource footprint low:

```text
Incoming HTTPS Request
       │
       ├──> Host: yourdomain.com ──> [ Routes to default Next.js pod ]
       │                             Renders main landing page & dashboard.
       │
       └──> Host: marcus.yourdomain.com ──> [ Routes to tenant-marcus pod ]
                                            Reads TENANT_ID=marcus.
                                            Automatically renders Marcus's profile page.
```

### How the Next.js Code Knows What to Render
To ensure the single container image behaves correctly based on the domain name, we use the `TENANT_ID` environment variable:

1.  **Main Platform Pods**: Started without a `TENANT_ID`. They render the main search page, registration forms, and auth paths.
2.  **Isolated Tenant Pods** (e.g. `tenant-marcus`): Started with the environment variable `TENANT_ID=marcus`.
3.  **Root Path Override**: In [src/app/page.tsx](file:///home/si3mshady/time-guild/src/app/page.tsx), if `process.env.NEXT_PUBLIC_TENANT_ID` is set, the root page `/` bypasses the main landing page and renders the creator detail view for that user automatically.

This ensures that visiting `marcus.yourdomain.com` loads the scheduling assistant instantly, while keeping all user data strictly isolated inside that creator's namespace.

---

## 3. Onboarding & DNS Resolution Workflow

This is a crucial concept: **in a wildcard DNS setup, DNS propagation only happens once (on Day 3).**

When a new provider (like Marcus) onboards, **no new DNS records are created** in Namecheap or Cloudflare.

Here is the exact lifecycle of how resolution happens:

### Step 1: The Wildcard DNS "Catch-All" (Set up once on Day 3)
On Day 3, you create a single wildcard record in your DNS settings:
*   `*.yourdomain.com` ──> points to `YOUR_AWS_ELASTIC_IP`

Because of this wildcard, the global DNS network now knows: *"Any request that ends in `.yourdomain.com` should be sent to your EC2 instance."*
*   `marcus.yourdomain.com` resolves to your EC2 IP.
*   `sarah.yourdomain.com` resolves to your EC2 IP.
*   `nonexistent.yourdomain.com` resolves to your EC2 IP.

There is **never any DNS propagation wait time** for new users because the global DNS wildcard record is already active.

### Step 2: The Onboarding Flow (User registers)
When a creator named Marcus signs up:
1.  He picks the username `marcus`.
2.  The Next.js signup endpoint saves his profile in the database.
3.  Next.js makes a direct API call to your K3s cluster: *"Create a namespace `tenant-marcus` and register an Ingress rule matching host `marcus.yourdomain.com`."*
4.  This API call takes **under 3 seconds**.

### Step 3: Instant Access (No propagation delay)
1.  A client types `marcus.yourdomain.com` in their browser.
2.  DNS immediately routes the request to your EC2 instance (thanks to the wildcard `*`).
3.  The request hits **Traefik** (the K3s Ingress controller) on your EC2.
4.  Traefik reads the HTTP header `Host: marcus.yourdomain.com`, finds the matching Ingress rule, and routes the traffic to Marcus's pod in the `tenant-marcus` namespace.

#### What happens if they visit a username that doesn't exist?
If a user goes to `fakeuser.yourdomain.com`:
1.  DNS still routes the traffic to your EC2 instance.
2.  Traefik checks K3s for any Ingress matching `Host: fakeuser.yourdomain.com`.
3.  Since no user has registered that name and no Ingress rule exists, Traefik immediately returns a secure **`404 Not Found`** page.

---

## 4. Educational Resources & System Design References

For a detailed explanation of subdomain routing in Next.js and how wildcards behave in SaaS systems, check out these guides:
*   **Vercel Platforms Starter Kit (The Industry Standard for Next.js Multi-Tenancy)**:  
    [https://github.com/vercel/platforms](https://github.com/vercel/platforms)
*   **DEV Community Guide: Step-by-Step Multi-Tenant App with Next.js**:  
    [https://dev.to/search?q=Next.js%20multi-tenant%20subdomain](https://dev.to/search?q=Next.js%20multi-tenant%20subdomain)
