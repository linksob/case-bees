resource "aws_iam_role" "eventbridge_stepfunction_role" {
  name = "eventbridge_stepfunction_role"
  assume_role_policy = file("${path.module}/policies/trust/eventbridge_stepfunction_trust.json")
}

resource "aws_iam_role_policy" "eventbridge_stepfunction_policy" {
  name = "eventbridge_stepfunction_policy"
  role = aws_iam_role.eventbridge_stepfunction_role.id
  policy = file("${path.module}/policies/policy/eventbridge_stepfunction_policy.json")
}