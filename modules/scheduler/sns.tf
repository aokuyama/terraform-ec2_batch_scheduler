resource "aws_sns_topic" "success" {
  name = "${local.resource_name}-success"
}

resource "aws_cloudwatch_event_rule" "success" {
  name = "${local.resource_name}-success"
  event_pattern = jsonencode({
    source : ["aws.states"],
    detail-type : ["Step Functions Execution Status Change"]
    detail : {
      stateMachineArn : [
        aws_sfn_state_machine.send_command_to_ec2.arn,
      ]
      status : [
        "SUCCEEDED",
      ]
    }
  })
}

resource "aws_cloudwatch_event_target" "success" {
  rule = aws_cloudwatch_event_rule.success.name
  arn  = aws_sns_topic.success.arn

  input_transformer {
    input_paths = {
      id : "$.id"
      detailType : "$.detail-type"
      accountId : "$.account"
      region : "$.region"
      resource : "$.resources[0]"
      output : "$.detail.output"
    }
    input_template = templatefile("${path.module}/alarm_template.json", {
      name : local.resource_name
    })
  }
}

resource "aws_sns_topic_policy" "success" {
  arn    = aws_sns_topic.success.arn
  policy = data.aws_iam_policy_document.success.json
}

data "aws_iam_policy_document" "success" {
  statement {
    actions = ["sns:Publish"]
    effect  = "Allow"
    resources = [
      aws_sns_topic.success.arn,
    ]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudwatch_event_rule.success.arn]
    }
  }
}

resource "aws_chatbot_slack_channel_configuration" "success" {
  configuration_name = "${local.resource_name}-success-slack-notifications"
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_team_id      = var.slack.team_id
  slack_channel_id   = var.slack.channel_id.success
  sns_topic_arns     = [aws_sns_topic.success.arn]
}

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
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_team_id      = var.slack.team_id
  slack_channel_id   = var.slack.channel_id.error
  sns_topic_arns     = [aws_sns_topic.error.arn]
}

resource "aws_iam_role" "chatbot" {
  name = "${local.resource_name}-chatbot"
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
