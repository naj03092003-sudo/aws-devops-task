# Deployment Guide

Everything is deployed by the GitHub Actions pipeline. A one-time bootstrap (run from your laptop) creates the Terraform state bucket and the IAM roles the pipeline assumes via OIDC.

## 0. Prerequisites

- An AWS account and an IAM user/role with admin rights **for the one-time bootstrap only**
- AWS CLI v2 and Terraform >= 1.10 on your machine
- A domain you control with a **public Route 53 hosted zone** (ACM cannot issue a certificate for the raw `*.elb.amazonaws.com` name, so a domain is required for real HTTPS). Note the hosted zone ID, and pick the app hostname, e.g. `app.yourdomain.com`
- A GitHub repository for this code

```bash
aws sts get-caller-identity      # confirm you are in the right account
aws configure get region         # or just pass ap-south-1 below
```

## 1. Bootstrap (once)

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
# edit: github_repo = "<your-user>/<your-repo>", route53_zone_id = "Z..."
# if the account already has the GitHub OIDC provider, add: create_oidc_provider = false

terraform init
terraform apply
```

Note the three outputs: `state_bucket`, `plan_role_arn`, `apply_role_arn`.

## 2. Configure GitHub

Repository -> **Settings -> Secrets and variables -> Actions -> Variables** (these are not secrets; they contain no credentials):

| Variable | Value |
|---|---|
| `AWS_REGION` | `ap-south-1` |
| `TF_STATE_BUCKET` | bootstrap output `state_bucket` |
| `AWS_PLAN_ROLE_ARN` | bootstrap output `plan_role_arn` |
| `AWS_APPLY_ROLE_ARN` | bootstrap output `apply_role_arn` |
| `DOMAIN_NAME` | e.g. `app.yourdomain.com` |
| `ROUTE53_ZONE_ID` | your hosted zone ID |

Repository -> **Settings -> Environments -> New environment** named exactly `production`, then add yourself under **Required reviewers**. The apply role only trusts this environment, so nothing can change AWS without your approval.

## 3. Deploy

```bash
git init && git add . && git commit -m "Initial commit"
git branch -M main
git remote add origin git@github.com:<your-user>/<your-repo>.git
git push -u origin main
```

Pipeline flow on push to `main`:

1. **Validate** - `terraform fmt -check`, `terraform validate`, Checkov (informational), Python syntax check
2. **Plan** - read-only role, summary is shown on the run page
3. **Apply** - pauses for your approval on the `production` environment; click **Review deployments -> Approve**. Expect about 15-20 minutes (Multi-AZ RDS is the slow part)
4. **Smoke test** - waits for `/health`, checks the HTTP->HTTPS redirect, prints the TLS certificate, calls `/health/db` and `/storage-check`

For changes, open a pull request: validate + plan run automatically, and merging to `main` triggers apply.

## 4. Manual validation (for your screenshots)

```bash
URL=https://app.yourdomain.com

curl -sI  http://app.yourdomain.com | head -3        # 301 -> https
curl -sI  $URL | head -3                              # 200 over TLS
curl -s   $URL/health ; echo                          # {"status":"ok"}
curl -s   $URL/health/db ; echo                       # database reachable
curl -s   $URL/storage-check ; echo                   # object written to S3
for i in 1 2 3 4 5 6; do curl -s $URL/ | grep -E 'Instance|Availability'; done   # both AZs appear
```

In the AWS console confirm: target group shows 2 **healthy** targets in two AZs; RDS shows **Multi-AZ = Yes**, **Publicly accessible = No**, **Encrypted**; the ALB log bucket receives `alb/AWSLogs/...` objects a few minutes after traffic.

**Self-healing test** - terminate one instance (EC2 -> Instances -> Terminate). The site keeps serving from the other instance and the ASG launches a replacement within a few minutes.

**Rolling deploy test** - change the text in `app/app.py`, push through a PR and merge. The ASG performs an instance refresh without dropping below 50% healthy capacity.

**Shell access (no SSH)** - EC2 -> select instance -> Connect -> Session Manager. Boot log: `sudo tail -n 100 /var/log/user-data.log`; app log: `sudo journalctl -u app -n 100`.

## 5. Running Terraform locally instead (optional)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars        # set domain_name and route53_zone_id
cp backend.hcl.example backend.hcl                  # set the state bucket name
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## 6. Cost control and teardown

The two NAT gateways, ALB and Multi-AZ RDS are the main running costs, so destroy the stack as soon as you have your screenshots. For a cheaper demo set `single_nat_gateway = true` and `db_multi_az = false` in `terraform.tfvars` (or repository-level `TF_VAR_*` values).

- Pipeline: **Actions -> Terraform CI/CD -> Run workflow -> action: destroy** (needs the same approval)
- Then, locally: `cd bootstrap && terraform destroy` (empty the state bucket first if it asks)

## Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `aws_acm_certificate_validation` hangs | The hosted zone is not authoritative for the domain - check the registrar's name servers match the zone's NS records |
| Plan job: "Not authorized to perform sts:AssumeRoleWithWebIdentity" | `github_repo` in bootstrap does not match `owner/name` exactly, or the run is from a fork |
| Apply job never starts | The `production` environment has no approver or was not created with that exact name |
| Targets unhealthy | Wait for the 300 s grace period, then check `/var/log/user-data.log` through Session Manager (usually a failed package download - confirm the NAT gateway is up) |
| `/health/db` returns 503 | Check the DB security group source and that the secret version exists; `journalctl -u app` shows the error class |
| ALB creation fails with "Access Denied" for logs | The log bucket policy must exist first; re-run apply (the dependency is declared, so this indicates a partial earlier failure) |
