variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short name used as a prefix for all resources."
  type        = string
  default     = "devops-task"
}

variable "environment" {
  description = "Environment name (used in names and tags)."
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Fully qualified domain name for the app, e.g. app.example.com. An ACM certificate is issued for it."
  type        = string
}

variable "route53_zone_id" {
  description = "ID of the public Route 53 hosted zone that contains domain_name (used for ACM DNS validation and the alias record)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 for high availability."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper, not AZ-resilient). false = one NAT gateway per AZ."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "EC2 instance type for the application servers."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of application instances."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of application instances."
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Initial number of application instances."
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Name of the initial MySQL database."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the MySQL instance."
  type        = string
  default     = "appadmin"
}

variable "db_multi_az" {
  description = "Run RDS with a synchronous standby in a second AZ."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Protect the RDS instance from deletion. Keep false for this practical so terraform destroy works; set true in real environments."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. Set false in real environments."
  type        = bool
  default     = true
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window. 0 deletes immediately (lets you re-create the same secret name after destroy)."
  type        = number
  default     = 0
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection on the ALB."
  type        = bool
  default     = false
}

variable "alb_log_retention_days" {
  description = "Days to keep ALB access logs in S3."
  type        = number
  default     = 90
}

variable "s3_force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets. Convenient for this practical; set false in real environments."
  type        = bool
  default     = true
}
