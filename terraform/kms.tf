# One customer-managed key for RDS storage, Secrets Manager and the application S3 bucket.
# (EBS volumes use the AWS-managed aws/ebs key; ALB log buckets must use SSE-S3.)

resource "aws_kms_key" "main" {
  description             = "${local.name} data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.main.key_id
}
