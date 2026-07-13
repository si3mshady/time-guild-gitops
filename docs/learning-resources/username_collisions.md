# Strategy: Handling Username & Subdomain Collisions

This document outlines strategies for handling username collisions (e.g., two users named "Marcus") and subdomain conflicts as the Time Guild platform scales.

---

## 1. Current Behavior (First-Come, First-Served)
Currently, in [signup/route.ts](file:///home/si3mshady/time-guild/src/app/api/auth/signup/route.ts#L39-L43), the platform enforces strict unique usernames:
```typescript
const existingUsername = db.prepare("SELECT * FROM users WHERE LOWER(username) = LOWER(?)").get(username);
if (existingUsername) {
  return NextResponse.json({ error: "Username is already taken" }, { status: 400 });
}
```
If "Marcus Jenkins" signs up first, he gets `marcus.yourdomain.com`. If "Marcus Aurelius" signs up second, he is rejected and must pick another username (e.g., `marcus-aurelius`).

This is the standard industry pattern used by platforms like:
*   **GitHub**: `github.com/username`
*   **Slack**: `workspace.slack.com`
*   **Substack**: `username.substack.com`

---

## 2. Advanced Mitigation Strategies for Scale

As the platform grows, we can implement three progressive strategies to improve user experience and resolve collisions:

### Strategy A: Smart Auto-Suggestions (UX improvement)
*   **Concept**: If the database query finds `marcus` is taken, the signup UI doesn't just error. It queries availability and suggests related, valid subdomains.
*   **Suggestions Pattern**:
    *   *Appended Role*: `marcus-design`, `marcus-coach`, `marcus-consulting`
    *   *Appended Location*: `marcus-nyc`, `marcus-ca`
    *   *Simple Suffix*: `marcus1`, `marcus-dev`

### Strategy B: Subdomain + Short ID (The Discord / Hash Pattern)
*   **Concept**: Keep the username `marcus` but append a short, unique 4-character hex hash to the subdomain (e.g., `marcus-3f8a.yourdomain.com`).
*   **Pros**:
    *   Completely eliminates name-squatting and duplicate conflicts.
    *   Allows both creators to retain their preferred display name.
*   **Cons**:
    *   Subdomains are less clean and harder to memorize/share.

### Strategy C: Custom Domain Mapping (The Premium Solution)
*   **Concept**: Allow premium creators to configure their **own custom domains** (e.g., `booking.marcus.com` or `talktomarcus.com`) pointing to the cluster's ingress.
*   **Implementation (CNAME mapping)**:
    1.  The creator adds a CNAME record: `booking.marcus.com` ──> `yourdomain.com`.
    2.  Your Next.js provisioner creates an Ingress rule matching the host `booking.marcus.com` inside their `tenant-marcus` namespace.
    3.  cert-manager solves an HTTP-01 Let's Encrypt challenge for `booking.marcus.com` to secure it.
*   **Pros**: Highly professional, unlocks premium subscription tier, and bypasses your domain name collisions entirely.
