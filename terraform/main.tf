data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  app_dir = "${path.root}/../app"

  # Content hash of the application source (ignores __pycache__). Drives the S3 key of the
  # bundle and the launch template user_data, so a code change triggers an ASG instance refresh.
  app_files  = [for f in fileset(local.app_dir, "**") : f if !strcontains(f, "__pycache__")]
  app_hash   = sha256(join("", [for f in sort(local.app_files) : "${f}:${filesha256("${local.app_dir}/${f}")}"]))
  bundle_key = "artifacts/app-${substr(local.app_hash, 0, 16)}.zip"
}

data "archive_file" "app" {
  type        = "zip"
  source_dir  = local.app_dir
  output_path = "${path.module}/app.zip"
  excludes    = ["__pycache__"]
}

resource "aws_s3_object" "app_bundle" {
  bucket      = aws_s3_bucket.app.id
  key         = local.bundle_key
  source      = data.archive_file.app.output_path
  source_hash = local.app_hash

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.app]
}
