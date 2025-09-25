###################################SNS TOPIC#######################################
resource "aws_sns_topic" "bronze_to_silver_dq" {
  name = "bronze_to_silver_dq"
}

resource "aws_sns_topic_subscription" "bronze_to_silver_dq_email" {
  topic_arn = aws_sns_topic.bronze_to_silver_dq.arn
  protocol  = "email"
  endpoint  = "lincoln.sobral@hotmail.com"
}

output "bronze_to_silver_dq_topic_arn" {
  value = aws_sns_topic.bronze_to_silver_dq.arn
}