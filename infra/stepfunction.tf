#############################Step Function Role########################################
resource "aws_iam_role" "stepfunction_bees_brewery_role" {
  name = "stepfunction_bees_brewery_role"
  assume_role_policy = file("${path.module}/policies/trust/stepfunction_trust.json")
}

resource "aws_iam_role_policy" "stepfunction_bees_brewery_policy" {
  name   = "stepfunction_bees_brewery_policy"
  role   = aws_iam_role.stepfunction_bees_brewery_role.id
  policy = file("${path.module}/policies/policy/stepfunction_policy.json")
}
#####################################################################################
############################# Step Function #########################################


resource "aws_sfn_state_machine" "bees_brewery_pipeline" {
  name     = "bees-brewery-pipeline"
  role_arn = aws_iam_role.stepfunction_bees_brewery_role.arn
  definition = templatefile("${path.module}/../orchestration/stepfunction_bees_brewery_pipeline.json", {
    lambda_bronze_arn = aws_lambda_function.bronze_ingestion.arn
  })
}

#####################################################################################
############################# Step Function Trigger #################################
resource "aws_cloudwatch_event_rule" "stepfunction_bees_brewery_pipeline_trigger" {
  name                = "bees-brewery-stepfunction-trigger"
  description         = "Trigger Step Function pipeline diariamente às 03:10 UTC"
  schedule_expression = "cron(10 3 * * ? *)"
}

resource "aws_cloudwatch_event_target" "bees_brewery_pipeline_target" { 
  rule      = aws_cloudwatch_event_rule.stepfunction_bees_brewery_pipeline_trigger.name
  target_id = "stepfunction"
  arn       = aws_sfn_state_machine.bees_brewery_pipeline.arn
  role_arn  = aws_iam_role.eventbridge_stepfunction_role.arn
}
#####################################################################################