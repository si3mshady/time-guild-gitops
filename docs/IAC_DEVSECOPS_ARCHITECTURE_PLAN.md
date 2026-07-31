# Architecture Decision Record & Standalone IaC / DevSecOps Blueprint

**Document ID**: ADR-001-IAC-DEVSECOPS  
**Date**: July 31, 2026  
**Status**: APPROVED  
**Author**: Principal Platform Engineer & DevSecOps Architect  
**Target Systems**: `time-guild` (App), `time-guild-gitops` (GitOps/K8s), `time-guild-iac` (Standalone IaC)  

---

## Executive Summary & Architecture Decision Record (ADR)

### 1. Context & Codebase Inspection Findings
Based on an analysis of the repository context (`/home/si3mshady/time-guild` and `/home/si3mshady/time-guild-gitops`), the primary application footprint consists of:
* **Application Framework & Runtime**: Next.js 16 (React 19) packaged via Bun (`oven/bun:1.3.14-alpine`) running on port `3000`. The container build process requires `python3`, `make`, `g++`, `nodejs`, and `npm` to compile native binary bindings for `better-sqlite3`.
* **State & Persistence**: Dual database model utilizing a local file-based database (`time_worth.db`) alongside a cloud Supabase integration (`@supabase/supabase-js`).
* **Critical Business Logic**: Real Stripe Test/Developer Platform Connect integration (`stripe^22.3.0`, `@stripe/stripe-js^9.8.0`). The system executes platform consumer session checkouts, retains a 15% platform commission, and processes 85% creator payouts via `stripe.transfers.create` to connected Stripe Express accounts.
* **Integrations & Telemetry**: AI services via `@langchain/openai` & `@langchain/deepseek`, with OpenTelemetry node instrumentation (`@opentelemetry/sdk-node`) exporting traces via HTTP OTLP (`@opentelemetry/exporter-trace-otlp-http`).
* **Existing Infrastructure State**: Legacy/experimental Kubernetes manifests, Helm charts, and Docker Compose configurations exist in both repos (`infra/k8s`, `infra/helm`). However, operating Kubernetes at this stage introduces unnecessary operational overhead.

### 2. Architectural Decisions
1. **Compute Layer Selection (AWS ECS on Fargate)**: We choose **AWS ECS Fargate behind an Application Load Balancer (ALB)** as the primary compute target. ECS Fargate provides serverless container management, near-zero infrastructure maintenance overhead, native support for mounting AWS EFS (preserving local SQLite state during early phases), and an easy migration path to EKS/GitOps in the future.
2. **Repository Architecture**: Establish a **Standalone IaC Repository** (`time-guild-iac`) decoupled from the application repo (`time-guild`) and GitOps repo (`time-guild-gitops`). This decouples platform infrastructure lifecycles from application feature commits.
3. **AWS Boundary Strategy**: Implement an **AWS Organizations Multi-Account Architecture** (`Dev`, `Staging`, `Production`, and `Shared-Services`) to guarantee absolute blast-radius isolation and independent IAM security boundaries.
4. **State Management**: Standardize on a remote S3 backend with native S3 state locking (`use_lockfile = true`) enabled by Terraform >= 1.10, initialized via an idempotent **Bootstrap Module**.
5. **Keyless CI/CD Security**: Utilize **AWS IAM OpenID Connect (OIDC)** identity federation for GitHub Actions, completely eliminating long-lived AWS secret keys.
6. **DevSecOps Policy Gates**: Embed mandatory static code analysis, secret leak detection (TruffleHog), and IaC security compliance (Checkov/Tfsec) directly into GitHub Actions Pull Request gates.

---

## Step 1: Codebase Assessment & Integration Strategy

### 1. Repository Footprint & Runtime Requirements

| Domain | Finding | Engineering Impact on IaC / AWS Setup |
| :--- | :--- | :--- |
| **Runtime & Packaging** | Next.js 16 on Bun 1.3.14 Alpine (`Dockerfile` multi-stage build). | ECR repository needed with image tag immutability and vulnerability scanning on push. |
| **Storage / Database** | `better-sqlite3` (`time_worth.db`) + Supabase. | ECS Fargate tasks attach an AWS EFS Access Point to persist `time_worth.db`, with an upgrade path to AWS RDS PostgreSQL. |
| **Payment Operations** | Stripe Connect Checkout & Transfers (85/15 split). | AWS Secrets Manager must store `STRIPE_SECRET_KEY`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, and `NEXT_PUBLIC_STRIPE_TEST_MODE` for injection into container tasks. |
| **Telemetry** | OpenTelemetry Node Auto-Instrumentation. | ECS Task Definitions must configure `OTEL_EXPORTER_OTLP_ENDPOINT` pointing to AWS ADOT Collector or Datadog/Grafana agent. |

### 2. Three-Repository Integration Architecture

```
                                +---------------------------------------------------+
                                |             1. App Repo (time-guild)              |
                                |  Next.js 16, Bun, Stripe Logic, Dockerfile        |
                                +-------------------------+-------------------------+
                                                          |
                                      Pushes Versioned Docker Image via SHA
                                                          v
                                +---------------------------------------------------+
                                |            AWS ECR (Shared Services)              |
                                +-------------------------+-------------------------+
                                                          |
                                      Triggers Infrastructure Update
                                                          v
+---------------------------------------------------+     |     +---------------------------------------------------+
|            3. GitOps Repo (time-guild-gitops)    |     |     |          2. Standalone IaC Repo (time-guild-iac)  |
|  (Future Stage: EKS / ArgoCD / Helm Manifests)    |     +---->|  Terraform Modules, Multi-Env Specs, CI/CD Pipelines |
+---------------------------------------------------+           +-------------------------+-------------------------+
                                                                                          |
                                                                       Applies Provisioned Infra via OIDC
                                                                                          v
                                                                +---------------------------------------------------+
                                                                |              AWS Target Environments              |
                                                                |       [Dev]     ->     [Staging]    ->   [Prod]   |
                                                                +---------------------------------------------------+
```

### 3. Operational Workflow Mapping Across Layers

1. **Layer 1: Application Build & Image Release (`time-guild`)**
   - Developer pushes code to `main` in `time-guild`.
   - CI builds the container image via `Dockerfile`, tags it with the immutable Git commit SHA (e.g., `app:sha-a1b2c3d`), and pushes it to Amazon ECR in the Shared Services account.
2. **Layer 2: Infrastructure Provisioning & Container Orchestration (`time-guild-iac`)**
   - Terraform manages AWS VPCs, ALB listeners, ECS task definitions, EFS volumes, Secrets Manager, and IAM roles across `dev`, `staging`, and `production`.
   - When deploying a new application build, `time-guild-iac` receives the new image tag variable (`app_image_tag = "sha-a1b2c3d"`), updates the ECS Task Definition revision, and performs an in-place rolling update on ECS Fargate.
3. **Layer 3: AWS Runtime Execution (`AWS Target Environments`)**
   - ECS Fargate tasks boot inside private subnets behind an Application Load Balancer.
   - Tasks fetch `STRIPE_SECRET_KEY` and database credentials at launch from AWS Secrets Manager via IAM Task Execution Roles.
   - Stripe sandbox payouts and session checkouts execute against the Stripe API with zero exposed static credentials.

---

## Step 2: AWS Multi-Environment & GitHub Strategy

### 1. AWS Boundary Strategy: AWS Organizations Multi-Account Model
We specify an **AWS Organizations Multi-Account Strategy** over a single-account multi-VPC design to enforce zero-trust isolation between environments:

```
                          +-----------------------------------+
                          |      AWS Management Account       |
                          |   (AWS Organizations & Billing)   |
                          +-----------------+-----------------+
                                            |
        +-----------------------------------+-----------------------------------+
        |                                   |                                   |
+-------v-------------------+       +-------v-------------------+       +-------v-------------------+
|  Shared Services Account  |       |       Dev Account         |       |      Staging Account      |
|  - Central ECR Registry   |       |  - Dev VPC (10.10.0.0/16) |       | - Staging VPC (10.20.0.0) |
|  - S3 Terraform State     |       |  - Dev ECS Fargate Cluster|       | - Staging ECS Cluster     |
|  - Central OIDC Provider  |       |  - Dev EFS / Secrets      |       | - Staging EFS / Secrets   |
+---------------------------+       +---------------------------+       +---------------------------+
                                                                                |
                                                                        +-------v-------------------+
                                                                        |    Production Account     |
                                                                        | - Prod VPC (10.30.0.0/16) |
                                                                        | - Multi-AZ ECS Cluster    |
                                                                        | - Prod EFS / Secrets      |
                                                                        +---------------------------+
```

* **Trade-off Analysis**: While multi-account requires initializing OIDC trust policies per account, it prevents cross-environment contamination, isolates AWS API rate limits, simplifies security auditing, and provides clean per-environment cost allocation.

### 2. VPC & Networking Model

| Network Parameter | Dev Environment | Staging Environment | Production Environment |
| :--- | :--- | :--- | :--- |
| **VPC CIDR** | `10.10.0.0/16` | `10.20.0.0/16` | `10.30.0.0/16` |
| **Availability Zones** | 2 AZs (`us-east-1a`, `us-east-1b`) | 2 AZs (`us-east-1a`, `us-east-1b`) | 3 AZs (`us-east-1a`, `us-east-1b`, `us-east-1c`) |
| **Public Subnets** | `10.10.1.0/24`, `10.10.2.0/24` | `10.20.1.0/24`, `10.20.2.0/24` | `10.30.1.0/24`, `10.30.2.0/24`, `10.30.3.0/24` |
| **Private App Subnets** | `10.10.10.0/24`, `10.10.11.0/24` | `10.20.10.0/24`, `10.20.11.0/24` | `10.30.10.0/24`, `10.30.11.0/24`, `10.30.12.0/24` |
| **Database/Data Subnets**| `10.10.20.0/24`, `10.10.21.0/24` | `10.20.20.0/24`, `10.20.21.0/24` | `10.30.20.0/24`, `10.30.21.0/24`, `10.30.22.0/24` |
| **NAT Gateway Strategy** | Single NAT Gateway (Cost Optimized) | Single NAT Gateway | Highly Available Multi-AZ NAT Gateways |

### 3. IAM Role-Assumption Model for GitHub Actions (OIDC)
Eliminate permanent IAM user keys (`AWS_ACCESS_KEY_ID`). GitHub Actions authenticates directly via OpenID Connect (OIDC).

* **OIDC Provider Endpoint**: `https://token.actions.githubusercontent.com`
* **Audience**: `sts.amazonaws.com`
* **IAM Trust Relationship (Production Example)**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<PROD_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:my-org/time-guild-iac:environment:production"
        }
      }
    }
  ]
}
```

### 4. GitHub Environments Setup

Configure three GitHub Environments in `time-guild-iac`: `dev`, `staging`, and `production`.

```
                  GitHub Environments Configuration Matrix
+-------------------+--------------------------------+-----------------------------------+
| Environment       | Required Variables & Secrets   | Protection Rules & Gateways       |
+-------------------+--------------------------------+-----------------------------------+
| dev               | AWS_ROLE_ARN (Dev Role)        | - Automated auto-deploy on main   |
|                   | AWS_REGION="us-east-1"         | - No manual sign-off required     |
|                   | STRIPE_MODE="test"             |                                   |
+-------------------+--------------------------------+-----------------------------------+
| staging           | AWS_ROLE_ARN (Staging Role)    | - Automated deploy post-dev pass  |
|                   | AWS_REGION="us-east-1"         | - Automated integration testing   |
|                   | STRIPE_MODE="test"             |                                   |
+-------------------+--------------------------------+-----------------------------------+
| production        | AWS_ROLE_ARN (Prod Role)       | - Required Reviewers: 2 Lead Engs |
|                   | AWS_REGION="us-east-1"         | - Branch Restriction: 'main' only |
|                   | STRIPE_MODE="live"             | - Wait Timer: 15 minutes          |
+-------------------+--------------------------------+-----------------------------------+
```

---

## Step 3: Terraform Directory & State Management Architecture

### 1. Repository Directory Structure
The standalone repository `time-guild-iac` follows a clean Directory-Per-Environment design pattern:

```text
time-guild-iac/
├── .github/
│   └── workflows/
│       ├── pr-security-scan.yml
│       └── cd-infrastructure.yml
├── .gitleaks.toml
├── .tflint.hcl
├── README.md
├── bootstrap/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security_groups/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecr/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs_fargate/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── efs/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── secrets_manager/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── alb/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    ├── staging/
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── terraform.tfvars
    │   └── variables.tf
    └── production/
        ├── backend.tf
        ├── main.tf
        ├── outputs.tf
        ├── terraform.tfvars
        └── variables.tf
```

### 2. S3 State Backend & Bootstrap Workflow
To solve the "chicken-and-egg" issue of storing Terraform state in S3 before the S3 bucket exists, we utilize a dedicated `bootstrap` module.

#### Native S3 State Locking (`use_lockfile = true`)
Terraform 1.10+ introduces native S3 state locking using S3 object locks and conditional writes, eliminating the need for a separate DynamoDB table.

##### `bootstrap/main.tf` snippet:
```hcl
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_kms_key" "terraform_state_key" {
  description             = "KMS Key for Terraform State Buckets"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Project     = "time-guild"
    ManagedBy   = "Terraform"
    Environment = "shared"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  for_each      = toset(["dev", "staging", "production"])
  bucket        = "time-guild-tfstate-${each.key}-${var.aws_account_id}"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state_privacy" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

##### `environments/production/backend.tf` snippet:
```hcl
terraform {
  required_version = ">= 1.10.0"
  backend "s3" {
    bucket       = "time-guild-tfstate-production-123456789012"
    key          = "production/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Native S3 locking supported in Terraform 1.10+
  }
}
```

### 3. Foundational Modular Specifications

1. **`modules/vpc`**: Provisions multi-AZ VPC, Internet Gateway, public/private/data subnets, route tables, and NAT Gateways.
2. **`modules/security_groups`**: Restricts ingress to ALB (ports 80/443), limits ECS task ingress strictly to ALB Security Group on port 3000, and restricts EFS mount target ingress to ECS Task Security Group on port 2049.
3. **`modules/ecr`**: Provisions ECR repositories with image scan on push enabled and KMS encryption.
4. **`modules/ecs_fargate`**: Defines ECS Cluster, Fargate Task Definition (Bun runtime, container port 3000, CPU/Memory parameters), ECS Service with rolling deploy configuration, auto-scaling policy, and IAM Task/Execution roles.
5. **`modules/efs`**: Manages Elastic File System, KMS encryption, Mount Targets in private subnets, and EFS Access Point for mounting `/app/time_worth.db` into the Next.js container.
6. **`modules/secrets_manager`**: Stores `STRIPE_SECRET_KEY`, `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`, `JWT_SECRET`, and `DEEPSEEK_API_KEY`, injecting them securely into the ECS task execution environment.
7. **`modules/alb`**: Configures Application Load Balancer, ACM SSL Certificate, Target Group with HTTP health checks (`GET /api/health` or `/`), and HTTP-to-HTTPS redirect rules.

---

## Step 4: DevSecOps & GitHub Actions Pipeline Design

### 1. Pull Request Validation Pipeline (`pr-security-scan.yml`)

This pipeline executes on every Pull Request to ensure secret compliance, IaC policy adherence, and syntax validity before code can be merged.

```yaml
name: "DevSecOps PR Validation & Security Gate"

on:
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'bootstrap/**'
      - 'modules/**'
      - 'environments/**'

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  trufflehog-secret-scan:
    name: "TruffleHog Secret Scan"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run TruffleHog OSS
        uses: trufflesecurity/trufflehog-actions-scan@v3.88.15
        with:
          base: ${{ github.event.pull_request.base.sha }}
          head: ${{ github.event.pull_request.head.sha }}
          extra_args: --debug --only-verified

  checkov-iac-scan:
    name: "Checkov IaC Security Policy Scan"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Checkov Security Scan
        uses: bridgecrewio/checkov-action@master
        with:
          framework: terraform
          output_format: cli
          soft_fail: false

  terraform-lint-and-plan:
    name: "Terraform Format, Lint & Speculative Plan"
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, production]
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.50.0

      - name: Run TFLint
        run: |
          tflint --init
          tflint

      - name: Configure AWS Credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-iac-plan-role
          aws-region: us-east-1

      - name: Terraform Init & Plan (${{ matrix.environment }})
        working-directory: ./environments/${{ matrix.environment }}
        run: |
          terraform init
          terraform plan -no-color -out=tfplan
```

### 2. Continuous Deployment Pipeline (`cd-infrastructure.yml`)

Sequentially deploys infrastructure through environments with embedded security gates and manual sign-off before Production.

```yaml
name: "Continuous Infrastructure Deployment (CD)"

on:
  push:
    branches: [ main ]
    paths:
      - 'modules/**'
      - 'environments/**'

permissions:
  contents: read
  id-token: write

jobs:
  deploy-dev:
    name: "Deploy -> Dev Environment"
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"

      - name: Configure AWS Credentials (Dev OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Terraform Init & Apply (Dev)
        working-directory: ./environments/dev
        run: |
          terraform init
          terraform apply -auto-approve

  deploy-staging:
    name: "Deploy -> Staging Environment"
    needs: deploy-dev
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"

      - name: Configure AWS Credentials (Staging OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Terraform Init & Apply (Staging)
        working-directory: ./environments/staging
        run: |
          terraform init
          terraform apply -auto-approve

  deploy-production:
    name: "Deploy -> Production Environment"
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production # Contains manual approval protection rule
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.10.0"

      - name: Configure AWS Credentials (Prod OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Pre-Flight Stripe Config Verification Check
        run: |
          echo "Verifying Stripe Secret configuration in Secrets Manager..."
          aws secretsmanager describe-secret --secret-id time-guild/production/stripe --region us-east-1

      - name: Terraform Init & Apply (Production)
        working-directory: ./environments/production
        run: |
          terraform init
          terraform apply -auto-approve
```

---

## Step 5: Concrete Execution Roadmap

### 1. Phased Execution Checklist

```text
Phase 1: Bootstrapping State & IAM OIDC Setup
 ├── [ ] Create standalone GitHub repository `time-guild-iac`.
 ├── [ ] Execute `bootstrap` module locally to create remote S3 state buckets & KMS keys.
 ├── [ ] Deploy AWS OIDC Identity Provider and IAM execution roles in AWS Accounts.
 └── [ ] Populate GitHub Environment Secrets (`AWS_ROLE_ARN`) for `dev`, `staging`, and `production`.

Phase 2: Core Infrastructure Engineering
 ├── [ ] Write reusable Terraform modules (`vpc`, `security_groups`, `ecr`, `ecs_fargate`, `efs`, `secrets_manager`, `alb`).
 ├── [ ] Configure `environments/dev/` parameters (`10.10.0.0/16`, 2 AZs, Fargate 0.5 vCPU / 1GB RAM).
 ├── [ ] Configure `environments/staging/` parameters (`10.20.0.0/16`, 2 AZs).
 └── [ ] Configure `environments/production/` parameters (`10.30.0.0/16`, 3 AZs, Multi-AZ NAT, ALB SSL Cert).

Phase 3: DevSecOps & Pipeline Integration
 ├── [ ] Commit `.github/workflows/pr-security-scan.yml` with TruffleHog and Checkov scanners.
 ├── [ ] Commit `.github/workflows/cd-infrastructure.yml` with sequential environment promotion.
 ├── [ ] Configure GitHub Environment Protection Rules for `production` (2 manual approvers).
 └── [ ] Store app runtime secrets (`STRIPE_SECRET_KEY`, `JWT_SECRET`, etc.) in AWS Secrets Manager.

Phase 4: Initial Provisioning & Verification
 ├── [ ] Push initial infrastructure code to trigger `dev` environment provisioning.
 ├── [ ] Verify ECS Fargate task startup and EFS volume mount for `time_worth.db`.
 ├── [ ] Validate Stripe Sandbox session checkout & payout transfer execution against ALB domain.
 └── [ ] Verify automated environment promotion through Staging to Production gate.
```

### 2. Explicit CLI Commands for Phase 1 Execution

To kick off Phase 1 safely, run the following explicit commands on your workstation:

```bash
# 1. Initialize the new standalone repository structure
mkdir -p ~/time-guild-iac/{bootstrap,modules/{vpc,security_groups,ecr,ecs_fargate,efs,secrets_manager,alb},environments/{dev,staging,production},.github/workflows}
cd ~/time-guild-iac
git init

# 2. Authenticate to your AWS Shared Services / Management Account
export AWS_REGION="us-east-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# 3. Create the Bootstrap Terraform file for Remote State Buckets
cat <<'EOF' > bootstrap/main.tf
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type = string
}

resource "aws_kms_key" "terraform_state_key" {
  description             = "KMS Key for Terraform State Buckets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "terraform_state" {
  for_each      = toset(["dev", "staging", "production"])
  bucket        = "time-guild-tfstate-${each.key}-${var.aws_account_id}"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state_privacy" {
  for_each = aws_s3_bucket.terraform_state
  bucket   = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "s3_bucket_names" {
  value = { for k, v in aws_s3_bucket.terraform_state : k => v.id }
}
EOF

# 4. Provision the S3 State Buckets & KMS Encryption Keys
cd ~/time-guild-iac/bootstrap
terraform init
terraform apply -var="aws_account_id=${AWS_ACCOUNT_ID}" -auto-approve

# 5. Verify S3 Remote Buckets Creation
aws s3 ls | grep time-guild-tfstate
```
