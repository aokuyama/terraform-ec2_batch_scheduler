data "aws_caller_identity" "self" {}
data "aws_instance" "ec2" {
  instance_id = var.instance_id
}
variable "schedule" {
  type = map(object({
    description = string
    expression  = string
    timezone    = optional(string, "Asia/Tokyo")
    commands    = list(string)
  }))
}

resource "aws_scheduler_schedule_group" "this" {
  name = var.env
}

resource "aws_scheduler_schedule" "batch" {
  for_each = var.schedule

  group_name                   = aws_scheduler_schedule_group.this.name
  name                         = each.key
  description                  = each.value.description
  schedule_expression          = each.value.expression
  schedule_expression_timezone = each.value.timezone
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sfn_state_machine.send_command_to_ec2.arn
    role_arn = aws_iam_role.this.arn

    input = jsonencode({
      commandId = "/${local.log_prefix}/${each.key}"
      sendCommand = {
        commands               = each.value.commands
        workingDirectory       = ["/opt/aws"]
        cloudWatchLogGroupName = "/${local.log_prefix}/${each.key}"
      }
    })
    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.env}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role_policy.json
  managed_policy_arns = [
    aws_iam_policy.execute_sfn.arn,
  ]
}

data "aws_iam_policy_document" "scheduler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "execute_sfn" {
  name   = "${var.env}-scheduler-execute-sfn"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.execute_sfn.json
}

data "aws_iam_policy_document" "execute_sfn" {
  statement {
    actions = ["states:StartExecution"]
    effect  = "Allow"
    resources = [
      aws_sfn_state_machine.send_command_to_ec2.arn,
    ]
  }
}
