# Screenshot checklist

Save images in `docs/screenshots/` using the names below, then reference them from the README if you like.

| # | File name | What to capture |
|---|---|---|
| 1 | `01-actions-pipeline.png` | GitHub Actions run with all jobs green (validate, plan, apply, smoke-test) |
| 2 | `02-approval-gate.png` | The "Review deployments" approval prompt for the `production` environment |
| 3 | `03-smoke-test-log.png` | Smoke-test job log showing the 301 redirect, certificate, and `/health/db` result |
| 4 | `04-app-https.png` | Browser on `https://<your-domain>` showing the padlock and the instance/AZ page |
| 5 | `05-vpc-subnets.png` | VPC resource map showing public / private-app / private-db subnets across 2 AZs |
| 6 | `06-route-tables.png` | Public route table (IGW), app route tables (NAT), DB route table (local only) |
| 7 | `07-alb-listeners.png` | ALB listeners: 443 -> forward (ACM cert) and 80 -> redirect to 443 |
| 8 | `08-target-group-healthy.png` | Target group with healthy targets in both AZs |
| 9 | `09-asg-launch-template.png` | ASG details: min 2 / max 4, scaling policy, launch template (IMDSv2 required) |
| 10 | `10-rds-config.png` | RDS: Multi-AZ, encrypted, not publicly accessible, private subnet group |
| 11 | `11-security-groups.png` | The three security groups' inbound rules (ALB, app, DB) |
| 12 | `12-secrets-manager.png` | The secret (do **not** reveal the password value) |
| 13 | `13-iam-role-policy.png` | Instance role and its least-privilege policy |
| 14 | `14-s3-buckets.png` | App bucket and ALB-log bucket, with encryption + block-public-access settings |
| 15 | `15-alb-logs-in-s3.png` | `alb/AWSLogs/...` objects in the log bucket |
| 16 | `16-acm-certificate.png` | ACM certificate status "Issued" |
| 17 | `17-self-healing.png` | (Optional) ASG activity history after terminating an instance |

Before sharing: blur or crop AWS account IDs if you prefer, and never capture the secret value.
