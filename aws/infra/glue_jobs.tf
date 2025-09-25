############################################################################
################################ GLUE JOBS #################################
resource "aws_iam_role" "glue_bees_breweries_role" {
  name = "glue_bees_breweries_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_bees_breweriess3" {
  role       = aws_iam_role.glue_bees_breweries_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "glue_bees_breweries_glue" {
  role       = aws_iam_role.glue_bees_breweries_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_bees_breweries_logs" {
  role       = aws_iam_role.glue_bees_breweries_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy" "glue_bees_breweries_sns" {
  name = "glue_bees_breweries_sns"
  role = aws_iam_role.glue_bees_breweries_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = "arn:aws:sns:sa-east-1:418295684947:bronze_to_silver_dq"
      }
    ]
  })
}

################################ UPLOAD SCRIPTS #################################
resource "aws_s3_object" "bronze_to_silver_script" {
  bucket = "bees-brewery-scripts"
  key    = "glue_jobs/job-bronze_to_silver.py"
  source = "${path.module}/../glue_jobs/job-bronze_to_silver.py"
  etag   = filemd5("${path.module}/../glue_jobs/job-bronze_to_silver.py")
}

resource "aws_s3_object" "silver_to_gold_script" {
  bucket = "bees-brewery-scripts"
  key    = "glue_jobs/job-silver_to_gold.py"
  source = "${path.module}/../glue_jobs/job-silver_to_gold.py"
  etag   = filemd5("${path.module}/../glue_jobs/job-silver_to_gold.py")
}
#################################################################################
################################ GLUE JOBS DEFINITION ###########################
# Bronze to Silver
resource "aws_glue_job" "job_bronze_to_silver" {
  name     = "job-bronze_to_silver"
  role_arn = aws_iam_role.glue_bees_breweries_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/glue_jobs/job-bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--BRONZE_PATH"   = "s3://${aws_s3_bucket.bronze.bucket}/bronze/"
    "--SILVER_PATH"   = "s3://${aws_s3_bucket.silver.bucket}/tb_bees_breweries_silver/"
    "--DATABASE_NAME" = aws_glue_catalog_database.db_bees_silver.name
    "--TABLE_NAME"    = aws_glue_catalog_table.tb_bees_breweries_silver.name
    "--TempDir"       = "s3://${aws_s3_bucket.scripts.bucket}/glue_temp/"
    "--job-language"  = "python"
    "--additional-python-modules" = "unidecode"
  }

  max_retries      = 0
  glue_version     = "4.0"
  number_of_workers = 2
  worker_type      = "G.1X"
}

# Silver to Gold
resource "aws_glue_job" "job_silver_to_gold" {
  name     = "job-silver_to_gold"
  role_arn = aws_iam_role.glue_bees_breweries_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/glue_jobs/job-silver_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--SILVER_PATH"   = "s3://${aws_s3_bucket.silver.bucket}/tb_bees_breweries_silver/"
    "--GOLD_PATH"     = "s3://${aws_s3_bucket.gold.bucket}/tb_bees_breweries_gold/"
    "--DATABASE_NAME" = aws_glue_catalog_database.db_bees_gold.name
    "--TABLE_NAME"    = "tb_bees_breweries_gold"
    "--TempDir"       = "s3://${aws_s3_bucket.scripts.bucket}/glue_temp/"
    "--job-language"  = "python"
  }

  max_retries      = 0
  glue_version     = "4.0"
  number_of_workers = 2
  worker_type      = "G.1X"
}

############################################################################
