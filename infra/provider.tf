data "aws_caller_identity" "current" {}

provider "aws" {
  region = var.aws_region
}

#resource "aws_lakeformation_data_lake_settings" "default" {
#  admins = [
#    data.aws_caller_identity.current.arn
#    # "arn:aws:iam::123456789012:role/lakeformation-admins"
#  ]
#}
#
#resource "aws_iam_policy" "lakeformation_put_settings" {
#  name   = "lakeformation-put-settings"
#  policy = <<EOF
#{
#  "Version": "2012-10-17",
#  "Statement": [
#    {
#      "Effect": "Allow",
#      "Action": [
#        "lakeformation:PutDataLakeSettings"
#      ],
#      "Resource": "*"
#    }
#  ]
#}
#EOF
#}
#
#resource "aws_iam_user_policy_attachment" "docker_user_lakeformation_put_settings" {
#  user       = "docker_user"
#  policy_arn = aws_iam_policy.lakeformation_put_settings.arn
#}