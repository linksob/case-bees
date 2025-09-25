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