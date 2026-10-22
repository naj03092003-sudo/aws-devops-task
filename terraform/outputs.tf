output "app_url" {
  description = "Public HTTPS URL of the application."
  value       = "https://${var.domain_name}"
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "app_bucket" {
  value = aws_s3_bucket.app.id
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.logs.id
}
