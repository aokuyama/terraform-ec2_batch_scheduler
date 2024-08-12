resource "aws_sns_topic" "states" {
  name = "${local.resource_name}-states"
}

resource "aws_cloudwatch_event_rule" "states" {
  name = "${local.resource_name}-states"
  event_pattern = jsonencode({
    source : ["aws.states"],
    detail-type : ["Step Functions Execution Status Change"]
    detail : {
      stateMachineArn : [
        aws_sfn_state_machine.send_command_to_ec2.arn,
      ]
      status : [
        "SUCCEEDED",
        "FAILED",
        "TIMED_OUT",
        "ABORTED",
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "states" {
  rule = aws_cloudwatch_event_rule.states.name
  arn  = aws_sns_topic.states.arn
}

resource "aws_sns_topic_policy" "states" {
  arn    = aws_sns_topic.states.arn
  policy = data.aws_iam_policy_document.states.json
}

data "aws_iam_policy_document" "states" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.states.arn,
    ]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudwatch_event_rule.states.arn]
    }
  }
}

resource "aws_chatbot_slack_channel_configuration" "states" {
  configuration_name = "${local.resource_name}-states-slack-notifications"
  iam_role_arn       = aws_iam_role.states.arn
  slack_team_id      = var.slack.team_id
  slack_channel_id   = var.slack.channel_id
  sns_topic_arns     = [aws_sns_topic.states.arn]
}

resource "aws_iam_role" "states" {
  name = "${local.resource_name}-states-slack-notifications"
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
