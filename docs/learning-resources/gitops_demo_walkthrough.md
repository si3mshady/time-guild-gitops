# GitOps Continuous Delivery Video Demo Guide

This walkthrough guide outlines how to demonstrate the GitOps flow in action for your video. It defines a highly prominent, reversible code change you can make to show K3s and ArgoCD synchronizing the live cluster state automatically.

---

## 1. Preparation: What to Have Open

1.  **Tab 1 (Browser)**: Your local/dev web application home page (`http://localhost` or `http://timeguild.xyz`). Note the green **"Now in private beta"** badge in the hero section.
2.  **Tab 2 (Browser)**: The ArgoCD Dashboard (`https://argocd.timeguild.xyz` or local equivalent). Select the `timeguild-dev` application.
3.  **Terminal (Split Screen)**: Split your terminal into two sessions:
    *   **Terminal 1**: A live-watch of the rollout status:
        ```bash
        watch -n 0.5 "kubectl get pods -n timeguild-dev"
        ```
    *   **Terminal 2**: A command line ready to execute git commits.

---

## 2. Step-by-Step Demo Execution

### Step A: Make the Prominent Change (Visual Flag)
Open [src/app/page.tsx](file:///home/si3mshady/time-guild/src/app/page.tsx) and find the badge at line 30-32:
```tsx
            <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-card/60 px-3 py-1 text-xs text-muted-foreground backdrop-blur">
              <span className="size-1.5 rounded-full bg-emerald-500" /> Now in private beta
            </div>
```
Modify it to a pulsing red **GitOps Live Sync** banner:
```tsx
            <div className="inline-flex items-center gap-2 rounded-full border border-rose-500/50 bg-rose-500/10 px-3 py-1 text-xs text-rose-400 backdrop-blur">
              <span className="size-1.5 rounded-full bg-rose-500 animate-pulse" /> GitOps Live Sync Demo
            </div>
```

---

### Step B: Commit and Push to Trigger the CI/CD Pipeline
In your terminal, run the following:
```bash
git add src/app/page.tsx
git commit -m "feat: trigger GitOps sync with visual banner change"
git push origin main
```
*   **Narration**: *"I’ve just pushed a change to the main branch modifying our hero section badge to a pulsing red 'GitOps Live Sync' alert. This commit automatically triggers our GitHub Actions pipeline to compile the new Docker image."*

---

### Step C: Watch the Auto-Promotion & ArgoCD Sync
1.  After a minute, the GitHub Action compiles the image and pushes a tag promotion commit (e.g. `promote image to tag sha-<commit_hash>`) to your `time-guild-gitops` repository.
2.  **ArgoCD Auto-Detects**: Look at the ArgoCD Dashboard. It will immediately show `timeguild-dev` status transition to **OutOfSync** as it reads the new image tag in Git.
3.  **ArgoCD Reconciles**: Since auto-sync/self-heal is enabled, ArgoCD automatically triggers a rollout.
4.  **Watch the Rollout**: Show the Terminal window. You will see a new container transition from `ContainerCreating` to `Running`, and the old container get terminated.
*   **Narration**: *"Once the build finishes, the promotion script patches our GitOps repository. ArgoCD immediately detects the delta between our cluster's live state and our Git repository. Since self-healing is active, it automatically triggers a rolling deployment of our new container container without any manual kubectl commands."*

---

### Step D: Refresh the Browser to Confirm Live Change
Go back to your browser tab (`http://timeguild.xyz`) and hit refresh. The badge will now be red, pulsing, and read **"GitOps Live Sync Demo"**.
*   **Narration**: *"And there it is! The changes are live, compiled, synchronized, and routed over HTTPS in real-time. No manual deployment commands, no server restarts—pure declarative GitOps."*

---

### Step E: Revert Back to Original State
To restore your original layout, simply run:
```bash
git revert HEAD --no-edit
git push origin main
```
*   **Narration**: *"Reverting this update is as simple as reverting our Git history. I push a revert commit, and the entire reconciliation loop repeats itself, returning the cluster safely to our desired production state."*
