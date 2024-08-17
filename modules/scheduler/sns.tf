resource "aws_sns_topic" "error" {
  name = "${local.resource_name}-error"
}

resource "aws_cloudwatch_event_rule" "error" {
  name = "${local.resource_name}-error"
  event_pattern = jsonencode({
    source : ["aws.states"],
    detail-type : ["Step Functions Execution Status Change"]
    detail : {
      stateMachineArn : [
        aws_sfn_state_machine.send_command_to_ec2.arn,
      ]
      status : [
        "FAILED",
        "TIMED_OUT",
        "ABORTED",
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "error" {
  rule = aws_cloudwatch_event_rule.error.name
  arn  = aws_sns_topic.error.arn
}

resource "aws_sns_topic_policy" "error" {
  arn    = aws_sns_topic.error.arn
  policy = data.aws_iam_policy_document.error.json
}

data "aws_iam_policy_document" "error" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.error.arn,
    ]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudwatch_event_rule.error.arn]
    }
  }
}

resource "aws_chatbot_slack_channel_configuration" "error" {
  configuration_name = "${local.resource_name}-error-slack-notifications"
  iam_role_arn       = aws_iam_role.error.arn
  slack_team_id      = var.slack.team_id
  slack_channel_id   = var.slack.channel_id
  sns_topic_arns     = [aws_sns_topic.error.arn]
}

resource "aws_iam_role" "error" {
  name = "${local.resource_name}-error-slack-notifications"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "chatbot.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSResourceExplorerReadOnlyAccess"]
}
