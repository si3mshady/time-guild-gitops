# Day 3: AWS EC2 Prep, Elastic IP, DNS, & K3s Verification

Tomorrow, you will resume your work starting with this file.

---

## 1. Architectural Rationale: Why We Do This

*   **AWS Elastic IP (Static IP)**: By default, EC2 instances receive a dynamic public IP that changes whenever the instance is stopped or restarted. If the IP changes, your Namecheap DNS records break. An Elastic IP binds a permanent, static IP address to your server so your DNS remains rock-solid.
*   **Wildcard DNS (`*.yourdomain.com`)**: Instead of calling Namecheap/Cloudflare APIs to create a new DNS record every time a user signs up (which takes minutes to propagate globally), we configure a single wildcard record once. Any subdomain is instantly routed to your EC2 instance globally without delay or API rate limits.
*   **API Port Lockdown (6443)**: The Kubernetes API port (6443) is the control plane for your entire cluster. Leaving this open to the public internet makes your cluster vulnerable to automated scanner bots and brute-force attacks. Restricting it strictly to your local home IP secures the cluster edge.

---

## 2. Core Tasks

### A. AWS Network Security Setup
1.  Allocate an **AWS Elastic IP (EIP)** and associate it with your EC2 instance.
2.  Configure your EC2 **Security Groups**:
    *   Open Port `80` (HTTP) to `0.0.0.0/0` (public web access).
    *   Open Port `443` (HTTPS) to `0.0.0.0/0` (public secure web access).
    *   Open Port `6443` (Kubernetes API) **strictly** to your local home IP address (e.g. `203.0.113.5/32`).

### B. Namecheap Wildcard DNS Configuration
Configure your Namecheap DNS zone to resolve all traffic to your EIP:
1.  **A Record**: Host `@` ──> Value `YOUR_AWS_ELASTIC_IP`
2.  **Wildcard A Record**: Host `*` ──> Value `YOUR_AWS_ELASTIC_IP`

### C. Local Kubeconfig Access Setup
Since K3s is already installed on the EC2 host:
1.  SSH into your EC2 instance and read the kubeconfig credentials file:
    ```bash
    sudo cat /etc/rancher/k3s/k3s.yaml
    ```
2.  Copy the content, create a file locally at `~/.kube/config`, and paste it.
3.  Modify the server URL line in your local `~/.kube/config`:
    *   Change `server: https://127.0.0.1:6443` to `server: https://YOUR_AWS_ELASTIC_IP:6443`.
4.  Verify remote connectivity from your local CLI:
    ```bash
    kubectl get nodes
    ```

---

## 3. Study & Reference Materials
*   **K3s Quick-Start and Architecture**: Learn why K3s is preferred for lightweight single-node cloud environments:  
    [https://docs.k3s.io/quick-start](https://docs.k3s.io/quick-start)
*   **AWS Elastic IP (EIP) Guide**: Understand how static IPs protect routing endpoints from changing during instance restarts:  
    [https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html)
*   **How Wildcard DNS Resolution Works**: Learn how the `*` record directs dynamic subdomains (`avery.yourdomain.com`) to a single IP address:  
    [https://www.cloudflare.com/learning/dns/dns-records/dns-a-record/](https://www.cloudflare.com/learning/dns/dns-records/dns-a-record/)
