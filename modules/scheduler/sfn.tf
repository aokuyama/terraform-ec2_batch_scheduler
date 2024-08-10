resource "aws_iam_role" "sfn" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    aws_iam_policy.sendcommand.arn,
  ]
}

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
          MaxConcurrency  = "50"
          MaxErrors       = "50"
          Parameters = {
            workingDirectory = [""]
            executionTimeout = ["3600"]
            commands         = ["whoami", "pwd"]
          }
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
