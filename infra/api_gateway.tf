##############################API GATEWAY GOLD #################################
resource "aws_api_gateway_rest_api" "gold_api" {
  name        = "gold-api"
  description = "API for consulting tb_bees_brewery_gold"
}

resource "aws_api_gateway_resource" "gold" {
  rest_api_id = aws_api_gateway_rest_api.gold_api.id
  parent_id   = aws_api_gateway_rest_api.gold_api.root_resource_id
  path_part   = "gold"
}

resource "aws_api_gateway_method" "gold_get" {
  rest_api_id   = aws_api_gateway_rest_api.gold_api.id
  resource_id   = aws_api_gateway_resource.gold.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "gold_lambda" {
  rest_api_id = aws_api_gateway_rest_api.gold_api.id
  resource_id = aws_api_gateway_resource.gold.id
  http_method = aws_api_gateway_method.gold_get.http_method
  integration_http_method = "POST"
  type        = "AWS_PROXY"
  uri         = aws_lambda_function.api_gold.invoke_arn
  depends_on  = [aws_lambda_function.api_gold]
}

resource "aws_api_gateway_deployment" "gold" {
  depends_on = [aws_api_gateway_integration.gold_lambda]
  rest_api_id = aws_api_gateway_rest_api.gold_api.id
}

resource "aws_api_gateway_stage" "gold" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.gold_api.id
  deployment_id = aws_api_gateway_deployment.gold.id
}

resource "aws_lambda_permission" "apigw_gold" {
  statement_id  = "AllowAPIGatewayInvokeGold"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_gold.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.gold_api.execution_arn}/*/*"
}
###########################################################################