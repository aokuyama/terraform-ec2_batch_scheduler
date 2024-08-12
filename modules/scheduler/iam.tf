resource "aws_iam_policy" "logger" {
  name = "${local.resource_name}-log"
  path = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "logs:CreateLogGroup",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.self.account_id}:log-group:/${local.log_prefix}/*"
        },
        {
          Action = [
            "logs:CreateLogStream",
            "logs:DescribeLogStreams",
            "logs:PutLogEvents",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.self.account_id}:log-group:/${local.log_prefix}/*:log-stream*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}
