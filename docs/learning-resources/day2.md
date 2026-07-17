# Day 2: Production Containerization, Docker Hub, & CI/CD

> [!NOTE]
> **Status: COMPLETED**

On Day 2, we focused on cleaning up technical debt, preparing the production Docker image, and automating builds via GitHub Actions.

---

## 1. Core Tasks Completed

### A. Cleaned Up Overlapping Configurations
We removed all deprecated files related to TanStack Start, TanStack Router, and Vite, keeping the application purely unified under Next.js:
*   Deleted `vite.config.ts`, `src/routes/` directory, `src/routeTree.gen.ts`, `src/router.tsx`, `src/start.ts`, `src/server.ts`, and deprecated Supabase auth middlewares.
*   Cleaned [package.json](file:///home/si3mshady/time-guild/package.json) dependencies to keep only Next.js and standard react-query modules.
*   Successfully ran `bun install` to update the lockfile.
*   Verified that the Next.js production build (`bun run build`) compiles cleanly with zero errors.

### B. CI/CD Pipeline Configuration
Created the GitHub Actions workflow at **[.github/workflows/docker-publish.yml](file:///home/si3mshady/time-guild/.github/workflows/docker-publish.yml)**:
*   Triggers on pushes to the `main` branch.
*   Uses Docker Buildx to build a production image from the root [Dockerfile](file:///home/si3mshady/time-guild/Dockerfile).
*   Pushes the image to your Docker Hub repository under tags `latest` and the short commit SHA.

---

## 2. Study & Reference Materials
To understand the containerization and CI/CD tools used today, review:
*   **Docker Multi-Stage Builds Guide**: Learn how we separate builder environments from lightweight runner environments to keep image size small:  
    [https://docs.docker.com/build/building/multi-stage/](https://docs.docker.com/build/building/multi-stage/)
*   **GitHub Actions Docker Publish Guide**: Understand how secrets authenticate the workflow with Docker Hub:  
    [https://docs.github.com/en/actions/publishing-packages/publishing-docker-images](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
*   **Next.js Docker Deployments**: Next.js official guidelines on deploying standalones:  
    [https://nextjs.org/docs/pages/building-your-application/deploying#docker-image](https://nextjs.org/docs/pages/building-your-application/deploying#docker-image)
