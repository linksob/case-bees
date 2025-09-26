################################################################################
################################ GLUE JOB ROLE #################################
resource "aws_iam_role" "glue_bees_breweries_role" {
  name = "glue_bees_breweries_role"
  assume_role_policy = file("${path.module}/policies/trust/glue_trust.json")
}

resource "aws_iam_role_policy" "glue_policy" {
  name   = "glue-custom-policy"
  role   = aws_iam_role.glue_bees_breweries_role.id
  policy = file("${path.module}/policies/policy/glue_policy.json")
}

################################ UPLOAD SCRIPTS #################################
resource "aws_s3_object" "bronze_to_silver_script" {
  bucket = "bees-brewery-scripts"
  key    = "glue_jobs/job_bronze_to_silver.py"
  source = "${path.module}/../glue_jobs/app/job_bronze_to_silver.py"
  etag   = filemd5("${path.module}/../glue_jobs/app/job_bronze_to_silver.py")
}

resource "aws_s3_object" "silver_to_gold_script" {
  bucket = "bees-brewery-scripts"
  key    = "glue_jobs/job_silver_to_gold.py"
  source = "${path.module}/../glue_jobs/app/job_silver_to_gold.py"
  etag   = filemd5("${path.module}/../glue_jobs/app/job_silver_to_gold.py")
}
#################################################################################
################################ GLUE JOBS DEFINITION ###########################
# Bronze to Silver
resource "aws_glue_job" "job_bronze_to_silver" {
  name     = "job_bees_brewery_bronze_to_silver"
  role_arn = aws_iam_role.glue_bees_breweries_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/glue_jobs/job_bronze_to_silver.py"
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
    "--SNS_TOPIC_ARN" = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:bees_alert_topic"
  }

  max_retries      = 0
  glue_version     = "4.0"
  number_of_workers = 2
  worker_type      = "G.1X"
}

# Silver to Gold
resource "aws_glue_job" "job_silver_to_gold" {
  name     = "job_bees_brewery_silver_to_gold"
  role_arn = aws_iam_role.glue_bees_breweries_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/glue_jobs/job_silver_to_gold.py"
    python_version  = "3"
  }

  default_arguments = {
    "--GOLD_PATH"     = "s3://${aws_s3_bucket.gold.bucket}/tb_bees_breweries_gold/"
    "--DATABASE_NAME" = aws_glue_catalog_database.db_bees_gold.name
    "--DATABASE_NAME_SILVER" = aws_glue_catalog_database.db_bees_silver.name
    "--TABLE_NAME"    = "tb_bees_breweries_gold"
    "--TABLE_NAME_SILVER"    = "tb_bees_breweries_silver"
    "--TempDir"       = "s3://${aws_s3_bucket.scripts.bucket}/glue_temp/"
    "--job-language"  = "python"
    "--SNS_TOPIC_ARN" = "arn:aws:sns:${var.aws_region}:${data.aws_caller_identity.current.account_id}:bees_alert_topic"
  }

  max_retries      = 0
  glue_version     = "4.0"
  number_of_workers = 2
  worker_type      = "G.1X"
}

############################################################################
