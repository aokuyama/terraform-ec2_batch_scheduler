resource "aws_sfn_state_machine" "send_command_to_ec2" {
  name     = "SendCommandToEc2StateMachine"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    StartAt = "SendCommandToEc2"
    States = {
      SendCommandToEc2 = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ssm:sendCommand"
        Parameters = {
          DocumentName    = "AWS-RunShellScript"
          DocumentVersion = "1"
          InstanceIds     = [var.instance_id]
          Parameters = {
            "workingDirectory.$" = "$.sendCommand.workingDirectory"
            "commands.$"         = "$.sendCommand.commands"
          }
          CloudWatchOutputConfig = {
            "CloudWatchLogGroupName.$" = "$.sendCommand.cloudWatchLogGroupName"
            CloudWatchOutputEnabled    = true
          }
          MaxConcurrency = "1"
          MaxErrors      = "1"
          TimeoutSeconds = 60
        }
        ResultPath = "$.SendCommandOut"
        Next       = "Wait"
      }
      Wait = {
        Type    = "Wait"
        Seconds = 5
        Next    = "GetCommandInvocation"
      }
      GetCommandInvocation = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:ssm:getCommandInvocation"
        Parameters = {
          "CommandId.$" = "$.SendCommandOut.Command.CommandId"
          InstanceId    = var.instance_id
        }
        ResultPath = "$.GetCommandInvocationOut"
        Next       = "Is InProgress"
      }
      "Is InProgress" = {
        Type = "Choice"
        Choices = [{
          Variable     = "$.GetCommandInvocationOut.Status"
          StringEquals = "InProgress"
          Next         = "Wait"
        }]
        Default = "Success"
      }
      Success = {
        Type = "Succeed"
      }
    }
  })
}

resource "aws_iam_role" "sfn" {
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role_policy.json
  managed_policy_arns = [
    aws_iam_policy.sendcommand.arn,
  ]
}

data "aws_iam_policy_document" "sfn_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "sendcommand" {
  name   = "${var.env}-scheduler-sendcommand"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.sendcommand.json
}

data "aws_iam_policy_document" "sendcommand" {
  statement {
    actions = ["ssm:SendCommand"]
    effect  = "Allow"
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      data.aws_instance.ec2.arn,
    ]
  }
  statement {
    actions = ["ssm:GetCommandInvocation"]
    effect  = "Allow"
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.self.account_id}:*",
    ]
  }
}
