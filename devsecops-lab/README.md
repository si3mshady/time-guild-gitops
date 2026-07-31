# 🛡️ Standalone DevSecOps Learning Lab

**Author**: Senior DevSecOps Architect & Platform Engineer  
**Scope**: Zero-to-Low-Cost CI/CD Pipeline, DevSecOps Automated Governance, Multi-Environment Build Promotion, and Modular Terraform  
**Path**: `/devsecops-lab`  

---

## 🏛️ Executive Summary & Architecture Decision Record (ADR)

### Context & Objective
The goal of this lab is to provide an isolated, hands-on environment for practicing **DevSecOps security gates**, **Infrastructure as Code (Terraform)**, and **build promotion mechanics (GitHub Actions)** without incurring heavy AWS infrastructure costs.

### Key Architectural Decisions
1. **Compute & Architecture (AWS Free Tier Optimization)**:
   - Uses **AWS ECS Fargate** with minimal task sizing (`256` CPU / `512MB` RAM) or EC2 `t3.micro` capacity behind an **Application Load Balancer (ALB)**.
   - **Database**: Single-AZ AWS RDS PostgreSQL on `db.t4g.micro` or `db.t3.micro` (750 hours/month Free Tier eligible).
2. **Zero-Cost Egress Network Strategy**:
   - Assigns `assign_public_ip = true` to public subnets for task boot, allowing container image pulls directly from ECR without requiring an expensive AWS NAT Gateway (~$33/month baseline cost).
   - Inbound access to ECS container instances is strictly restricted to ALB Security Group on port 3000.
3. **Directory-Per-Environment Terraform Pattern**:
   - Modular structure under `infra/modules/` (`network`, `database`, `compute`) parameterized across `infra/environments/{dev,staging,prod}`.
   - Standardized on native S3 remote state locking (`use_lockfile = true`) in Terraform >= 1.10.
4. **DevSecOps Security Governance**:
   - Automated Pull Request checks: **TruffleHog** (Secret Detection), **Checkov** (IaC Policy Scan), **Trivy** (Container Image Vulnerabilities), and **Next.js Lint/SAST**.

---

## 📐 Macro Architecture & Workflow Integration

```
                                  [Developer Commit / PR]
                                             |
                                             v
                           +-----------------------------------+
                           |     GitHub Actions PR Gate        |
                           |  - TruffleHog (Secret Scan)       |
                           |  - Checkov (IaC Static Scan)      |
                           |  - Trivy (Container Vuln Scan)    |
                           |  - Speculative Terraform Plan     |
                           +-----------------+-----------------+
                                             |
                                    [Merge to Main]
                                             v
                           +-----------------------------------+
                           |   Build & Push Container to ECR   |
                           |   Tag: sha-a1b2c3d & latest       |
                           +-----------------+-----------------+
                                             |
                                             v
                           +-----------------------------------+
                           |   1. Auto-Deploy -> Dev Env       |
                           |   (Terraform Apply + ECS Update)  |
                           +-----------------+-----------------+
                                             |
                                             v
                           +-----------------------------------+
                           |   2. Auto-Deploy -> Staging Env   |
                           |   (Integration Test Verification) |
                           +-----------------+-----------------+
                                             |
                                 [Manual Approval Gate]
                               (GitHub Env Protection)
                                             |
                                             v
                           +-----------------------------------+
                           |   3. Deploy -> Production Env     |
                           +-----------------------------------+
```

---

## 🔬 Micro Mechanics & Security Boundaries

### 1. Zero-Trust Security Group Boundary Chaining
Traffic flows unidirectionally across isolated Security Group boundaries:

$$\text{Internet (Port 80)} \xrightarrow{\quad\text{ALB SG}\quad} \text{Port 3000} \xrightarrow{\quad\text{ECS SG}\quad} \text{Port 5432} \xrightarrow{\quad\text{RDS SG}\quad} \text{Database}$$

```hcl
# Ingress restricted to ALB Security Group ID only
resource "aws_security_group" "ecs" {
  name   = "dev-ecs-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
}

# PostgreSQL ingress restricted to ECS Security Group ID only
resource "aws_security_group" "rds" {
  name   = "dev-rds-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}
```

### 2. Secret Injection Flow
DB credentials are generated dynamically in Terraform via `random_password`, stored securely in **AWS Secrets Manager**, and injected into the ECS task execution environment at container boot:

```json
"secrets": [
  {
    "name": "DB_PASSWORD",
    "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:devsecops-lab/dev/rds-credentials:password::"
  }
]
```

---

## 🧪 4 Weekend Hands-on DevSecOps Practice Drills

### Drill 1: Catching Leaked Secrets (TruffleHog)
**Goal:** Verify that TruffleHog blocks pull requests containing exposed credentials.
1. Create a feature branch: `git checkout -b drill/secret-test`
2. Add a dummy AWS key or database password string inside `devsecops-lab/app/src/app/page.tsx`:
   ```typescript
   const AWS_SECRET = "AKIAIOSFODNN7EXAMPLE_DO_NOT_USE";
   ```
3. Commit and open a PR to `main`.
4. **Expected Result:** The `Secret Gate: TruffleHog Scan` job in `.github/workflows/lab-devsecops-gate.yml` will fail immediately and block the merge.

### Drill 2: Catching Insecure Infrastructure (Checkov)
**Goal:** Verify that Checkov catches insecure Terraform resource definitions.
1. Create a feature branch: `git checkout -b drill/iac-test`
2. Edit `devsecops-lab/infra/modules/network/main.tf` to open PostgreSQL to the entire internet:
   ```hcl
   ingress {
     from_port   = 5432
     to_port     = 5432
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"] # ❌ INSECURE WORLD INGRESS
   }
   ```
3. Push and open a PR.
4. **Expected Result:** Checkov will flag policy violation CKV_AWS_24 ("Ensure no security groups allow ingress from 0.0.0.0/0 to port 5432") and fail the PR gate.

### Drill 3: Full Multi-Environment Promotion Run
**Goal:** Practice building a feature and watching it promote through `dev` -> `staging` -> `prod`.
1. Create a valid branch: `git checkout -b feature/ui-improvement`
2. Update the header title in `devsecops-lab/app/src/app/page.tsx`.
3. Commit and push. Open a PR to `main`.
4. Observe all 5 checks passing in `lab-devsecops-gate.yml`.
5. Merge the PR into `main`.
6. Watch `lab-build-and-push.yml` build the Docker image, tag it with `github.sha`, and push to ECR.
7. Open `lab-cd-promotion.yml` actions tab:
   - Observe automatic deployment to `dev`.
   - Observe automatic deployment to `staging`.
   - Observe the execution pause at `production` awaiting manual reviewer sign-off in GitHub Environments.
8. Click **Approve and deploy** to promote the build into `production`.

### Drill 4: Cost Teardown & Clean Up
**Goal:** Teardown all provisioned AWS cloud infrastructure to prevent trailing charges.
1. Open terminal in workspace root.
2. Run the automated teardown script:
   ```bash
   ./devsecops-lab/infra/destroy-all.sh
   ```
3. Verify that `dev`, `staging`, and `prod` environments output `Destroy complete! Resources: X destroyed.`
