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
    arn      = "arn:aws:scheduler:::aws-sdk:ssm:sendCommand"
    role_arn = aws_iam_role.this.arn

    input = jsonencode({
      CloudWatchOutputConfig = {
        CloudWatchLogGroupName  = "/${local.log_prefix}/${each.key}"
        CloudWatchOutputEnabled = true
      }
      DocumentName    = "AWS-RunShellScript"
      DocumentVersion = "1"
      InstanceIds = [
        data.aws_instance.ec2.id
      ]
      MaxConcurrency = "1"
      MaxErrors      = "1"
      Parameters = {
        commands         = each.value.commands,
        workingDirectory = ["/opt/aws"]
      }
      TimeoutSeconds = 30
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
    aws_iam_policy.sendcommand.arn,
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

resource "aws_iam_policy" "sendcommand" {
  name = "${var.env}-scheduler-sendcommand"
  path = "/service-role/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ssm:SendCommand",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
            data.aws_instance.ec2.arn,
          ]
        },
        {
          Action = [
            "ssm:GetCommandInvocation",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.self.account_id}:*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}
