################################ LAMBDA FUNCTION ###########################
# Upload ZIP
resource "aws_s3_bucket_object" "lambda_zip" {
  bucket = aws_s3_bucket.scripts.id
  key    = "lambda_bronze/lambda.zip"
  source = "dist/lambda.zip"
}

# IAM Role Lambda
resource "aws_iam_role" "lambda_role" {
  name = "brewery_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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
      BUCKET_BRONZE = aws_s3_bucket.bronze.bucket
    }
  }
}
###########################################################################

#############################TRIGGER LAMBDA ###############################
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