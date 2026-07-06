# Cloud Suite — Infrastructure

Terraform infrastructure for the **Cloud Suite** project: a containerized API (the "Nimbus API") running on AWS ECS Fargate, backed by a PostgreSQL database, fronted by a load balancer, and wrapped in monitoring/alerting.

Everything is provisioned in **`us-east-1`** and namespaced with the `project_name` prefix (default `cloud-suite`).

---

## Architecture at a glance

```
                          Internet
                             │
                             ▼  HTTP :80
                   ┌──────────────────────┐
                   │  Application LB (ALB) │   public subnets (2 AZs)
                   │   alb_security_group  │   allows :80 from 0.0.0.0/0
                   └──────────┬───────────┘
                              │ forward :80 → target group :8080
                              ▼
                   ┌──────────────────────┐
                   │   ECS Fargate tasks   │   private subnets (2 AZs)
                   │   Nimbus API :8080    │   desired_count = 2
                   │   ecs_security_group  │   only :8080 from ALB SG
                   └───┬───────────┬──────┘
          pull image   │           │  connect :5432
          + logs       │           ▼
                       │   ┌──────────────────┐
                       │   │  RDS PostgreSQL   │  private subnets
                       │   │  cloudsuitedb     │  rds_sg: :5432 from ECS SG only
                       │   └──────────────────┘
                       ▼
          ┌────────────────────────┐        outbound to internet
          │ ECR (image registry)   │        (ECR pull, etc.) via
          │ CloudWatch Logs        │        NAT Gateway in public subnet
          └────────────────────────┘

   Monitoring: CloudWatch alarms (ECS CPU, RDS CPU, ALB 5xx) ──► SNS ──► email
```

**Request path:** `Internet → IGW → ALB (public subnets, :80) → ECS Fargate tasks (private subnets, :8080) → RDS PostgreSQL (:5432)`

**Outbound path (tasks):** `ECS tasks (private) → NAT Gateway (public subnet) → IGW → Internet` — used to pull container images from ECR and reach other AWS services. Tasks have no public IPs.

---

## Modules

The root module ([main.tf](main.tf)) configures the AWS provider and wires four modules together. Data flows via module outputs → root → the next module's inputs.

| Module | Path | Responsibility |
|--------|------|----------------|
| **networking** | [modules/networking/](modules/networking/) | VPC, public/private subnets, Internet Gateway, NAT Gateway, route tables |
| **compute** | [modules/compute/](modules/compute/) | ECS Fargate cluster/service/task, ALB + target group + listener, ECR, IAM roles, ECS/ALB security groups, CloudWatch log group |
| **database** | [modules/database/](modules/database/) | RDS PostgreSQL instance, DB subnet group, RDS security group |
| **monitoring** | [modules/monitoring/](modules/monitoring/) | SNS topic + email subscription, CloudWatch alarms for ECS CPU, RDS CPU, and ALB 5xx |

### How the modules depend on each other

```
networking ──┬─► compute ──┬─► database ──┐
             │             │              ├─► monitoring
             └─────────────┴──────────────┘
```

1. **networking** runs first (no dependencies). It emits `vpc_id`, `public_subnet_1/2`, and `private_subnet_1/2`.
2. **compute** consumes the VPC and subnet IDs. It places the ALB in the public subnets and the ECS tasks in the private subnets. It emits `ecs_security_group_id`, `ecs_cluster_name`, `ecs_service_name`, and `alb_arn_suffix`.
3. **database** consumes the VPC/private subnets **and** `compute.ecs_security_group_id` — the RDS security group only allows inbound `:5432` from the ECS security group, so the DB is reachable exclusively from the API tasks. It emits `db_identifier`.
4. **monitoring** consumes identifiers from **compute** and **database** (`ecs_cluster_name`, `ecs_service_name`, `alb_arn_suffix`, `db_identifier`) to scope its CloudWatch alarms to the right resources.

---

## Module details

### networking
- **VPC** `10.0.0.0/16` with DNS support + hostnames enabled (so ECS/ECR resolve by hostname).
- **Public subnets** `10.0.1.0/24` (us-east-1a) and `10.0.2.0/24` (us-east-1b) — host the ALB and NAT Gateway; auto-assign public IPs.
- **Private subnets** `10.0.3.0/24` (us-east-1a) and `10.0.4.0/24` (us-east-1b) — host the ECS tasks and RDS; no public IPs.
- **Internet Gateway** gives public subnets a route to the internet (`0.0.0.0/0` → IGW).
- **NAT Gateway** (with an Elastic IP, in a public subnet) gives private subnets outbound-only internet access (`0.0.0.0/0` → NAT).
- Two AZs throughout for high availability.

### compute
- **ECS cluster** + **Fargate service** running `desired_count = 2` tasks across both private subnets.
- **Task definition:** 0.25 vCPU / 512 MB, container port `8080`, `awsvpc` network mode. Environment includes `PORT`, `AWS_REGION`, `S3_BUCKET`, `JWT_SECRET`, and a `DATABASE_URL` pointing at RDS (`sslmode=require`).
- **ECR repository** (`<project>-api`) holds the Docker image; the task pulls `:latest`.
- **ALB** (internet-facing) → **listener :80** → **target group :8080** (`target_type = ip`, required for Fargate). Health check on `/health`.
- **Security groups:** ALB SG allows `:80` from anywhere; ECS SG allows `:8080` only from the ALB SG.
- **IAM execution role** trusts `ecs-tasks.amazonaws.com` and attaches `AmazonECSTaskExecutionRolePolicy` (ECR pull + log writes) and `AmazonS3FullAccess`.
- **CloudWatch log group** `/ecs/<project>_api`, 7-day retention.

### database
- **RDS PostgreSQL 15**, `db.t3.micro`, 20 GB, database name `cloudsuitedb`, port `5432`.
- **DB subnet group** spans both private subnets.
- **RDS security group** allows inbound `:5432` **only** from the ECS security group.

### monitoring
- **SNS topic** with an **email subscription** (`notification_email`).
- **CloudWatch alarms** (all notify SNS):
  - ECS CPU ≥ 80% (2 × 120s periods)
  - RDS CPU ≥ 80% (2 × 120s periods)
  - ALB 5xx count ≥ 10 (2 × 120s periods)

---

## State backend

Remote state is stored in S3 with DynamoDB locking (configured in [main.tf](main.tf)):
- **Bucket:** `cloud-suite-terraform-state`
- **Key:** `terraform.tfstate`
- **Lock table:** `cloud-suite-terraform-locks`
- Encryption enabled.

---

## Inputs

Defined in [variables.tf](variables.tf); set values in `terraform.tfvars` or via `-var`.

| Variable | Default | Sensitive | Description |
|----------|---------|-----------|-------------|
| `aws_region` | `us-east-1` | no | AWS region for the provider |
| `vpc_cidr` | `10.0.0.0/16` | no | VPC CIDR range |
| `project_name` | `cloud-suite` | no | Prefix for all resource names |
| `db_username` | — | yes | RDS master username |
| `db_password` | — | yes | RDS master password |
| `jwt_secret` | — | yes | JWT signing secret for the API |
| `notification_email` | — | yes | Email address for SNS alarm notifications |

---

## Usage

Requires Terraform with the AWS provider `~> 6.0` (locked to `6.38.0`) and AWS credentials configured for `us-east-1`.

```bash
cd infra

terraform init      # initializes the S3 backend + downloads the AWS provider
terraform plan      # preview changes
terraform apply     # provision
```

The `terraform.tfvars` file supplies the sensitive inputs. After apply, the SNS email subscription must be **confirmed** from your inbox before alarm notifications will be delivered.

---

## ⚠️ Security notes

- **`terraform.tfvars` currently contains plaintext secrets** (DB credentials and the JWT secret). It's excluded from git by [.gitignore](.gitignore), but the values should be rotated and moved to **AWS Secrets Manager** (the RDS/task configs even note this). The `DATABASE_URL` and `JWT_SECRET` are also injected as plaintext env vars in the ECS task definition — consider sourcing these from Secrets Manager via the task's `secrets` block instead.
- The **ECS execution role has `AmazonS3FullAccess`**, which is broader than needed — scope it to the specific bucket(s) the API uses.
- The ALB listener serves **HTTP :80 only** (no TLS). Add an HTTPS listener + ACM certificate before exposing this publicly.
