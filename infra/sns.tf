###################################SNS TOPIC#######################################
resource "aws_sns_topic" "bees_alert_topic" {
  name = "bees_alert_topic"
}

resource "aws_sns_topic_subscription" "bees_alert_topic_email" {
  topic_arn = aws_sns_topic.bees_alert_topic.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

output "sns_topic_arn" {
  value = aws_sns_topic.bees_alert_topic.arn
}
####################################################################################