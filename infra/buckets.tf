resource "aws_athena_workgroup" "primary" {
  name = "primary"
  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena.bucket}/"
    }
  }
  force_destroy = true
}
############################ BUCKETS CREATION #############################
resource "aws_s3_bucket" "bronze" {
  bucket = var.bronze_bucket
  versioning { enabled = true }
}

resource "aws_s3_bucket" "silver" {
  bucket = var.silver_bucket
  versioning { enabled = true }
}

resource "aws_s3_bucket" "gold" {
  bucket = var.gold_bucket
  versioning { enabled = true }
}

resource "aws_s3_bucket" "scripts" {
  bucket = var.scripts_bucket
  versioning { enabled = true }
}

resource "aws_s3_bucket" "athena" {
  # Desativa o bloqueio de políticas públicas para permitir bucket policy customizada
  bucket = var.athena_bucket
  force_destroy = true

  lifecycle_rule {
    id      = "expire-1-day"
    enabled = true

    expiration {
      days = 1
    }
  }

  versioning {
    enabled = false
  }
}
  resource "aws_s3_bucket_public_access_block" "athena" {
    bucket                  = aws_s3_bucket.athena.id
    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
  }

resource "aws_s3_bucket_policy" "athena" {
  bucket = aws_s3_bucket.athena.id
  policy = templatefile("${path.module}/policies/policy/athena_bucket_policy.json", {
    lambda_role_arn   = aws_iam_role.lambda_role.arn,
    athena_bucket_arn = aws_s3_bucket.athena.arn
  })
}