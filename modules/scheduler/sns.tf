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
