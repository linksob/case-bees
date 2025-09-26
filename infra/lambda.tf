# IAM Role Lambda
resource "aws_iam_role" "lambda_role" {
  name = "brewery_lambda_role"
  assume_role_policy = file("${path.module}/policies/trust/lambda_trust.json")
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = file("${path.module}/policies/policy/lambda_policy.json")
}

################################ LAMBDA FUNCTION BRONZE ###########################
# Upload ZIP
resource "aws_s3_bucket_object" "lambda_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "lambda_bronze/lambda.zip"
  source = "dist/lambda.zip"
}

# lambda function
resource "aws_lambda_function" "bronze_ingestion" {
  function_name = "brewery-bronze-ingestion"
  handler       = "main.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  timeout = 180

  s3_bucket = aws_s3_bucket.scripts.id
  s3_key    = aws_s3_bucket_object.lambda_zip.key


  environment {
    variables = {
      BUCKET_BRONZE   = aws_s3_bucket.bronze.bucket
      SNS_TOPIC_ARN   = aws_sns_topic.bees_alert_topic.arn
    }
  }
}
###########################################################################

#############################TRIGGER LAMBDA BRONZE ###############################
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "brewery-daily-trigger"
  description         = "Trigger Lambda daily at 03:00 UTC"
  schedule_expression = "cron(0 3 * * ? *)"  # 
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "lambda"
  arn       = aws_lambda_function.bronze_ingestion.arn
}

resource "aws_lambda_permission" "allow_trigger" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bronze_ingestion.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}
############################################################################
################################ LAMBDA FUNCTION API GOLD ###########################
# Lambda API Gold
resource "aws_s3_bucket_object" "lambda_api_gold_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "lambda_api/lambda_api_gold.zip"
  source = "dist/lambda_api_gold.zip"
}

resource "aws_lambda_function" "api_gold" {
  function_name = "api-gold"
  handler       = "lambda_api_gold.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 60

  s3_bucket = aws_s3_bucket.scripts.id
  s3_key    = aws_s3_bucket_object.lambda_api_gold_zip.key

  environment {
    variables = {
      ATHENA_DB     = "db_bees_gold"
      ATHENA_TABLE  = "tb_bees_breweries_gold"
      ATHENA_OUTPUT = "s3://${aws_s3_bucket.athena.bucket}/"
    }
  }
}
