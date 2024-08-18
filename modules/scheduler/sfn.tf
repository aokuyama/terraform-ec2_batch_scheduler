resource "aws_sfn_state_machine" "send_command_to_ec2" {
  name     = "${var.env}-sendcommand-to-ec2"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    StartAt = "CheckLockCommandId",
    States = {
      CheckLockCommandId = {
        Type = "Choice"
        Choices = [
          {
            Variable  = "$.appCommandId"
            IsPresent = true,
            Next      = "LockCommand"
          }
        ]
        Default = "SendCommandToEc2"
      }
      LockCommand = {
        Type     = "Task",
        Resource = "arn:aws:states:::dynamodb:putItem",
        Parameters = {
          TableName = aws_dynamodb_table.state.name
          Item = {
            "appCommandId" = {
              "S.$" = "$.appCommandId"
            }
          }
          ConditionExpression = "attribute_not_exists(appCommandId)"
        }
        Next = "SendCommandToEc2",
        Catch = [
          {
            ErrorEquals = [
              "DynamoDB.ConditionalCheckFailedException"
            ]
            Next = "CommandAlreadyRunning"
          },
          {
            ErrorEquals = [
              "States.TaskFailed"
            ]
            Next = "HandleError"
          }
        ]
        ResultPath = null
      }
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
        Next       = "WaitForCommand"
      }
      WaitForCommand = {
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
        Next       = "IsInProgress"
      }
      IsInProgress = {
        Type = "Choice"
        Choices = [{
          Variable     = "$.GetCommandInvocationOut.Status"
          StringEquals = "InProgress"
          Next         = "WaitForCommand"
        }]
        Default = "CheckUnlockCommandId"
      }
      CheckUnlockCommandId = {
        Type = "Choice"
        Choices = [
          {
            Variable  = "$.appCommandId"
            IsPresent = true,
            Next      = "UnlockCommand"
          }
        ]
        Default = "CommandCompleted"
      }
      UnlockCommand = {
        Type     = "Task",
        Resource = "arn:aws:states:::dynamodb:deleteItem",
        Parameters = {
          TableName = aws_dynamodb_table.state.name
          Key = {
            "appCommandId" = {
              "S.$" = "$.appCommandId"
            }
          }
        }
        Next = "CommandCompleted"
        Catch = [
          {
            ErrorEquals = [
              "States.TaskFailed"
            ]
            Next = "HandleError"
          }
        ]
        ResultPath = null
      }
      CommandCompleted = {
        Type       = "Pass"
        ResultPath = "$.customMessage"
        Parameters = {
          "Message" = "Success"
        },
        OutputPath = "$.customMessage",
        Next       = "Success"
      }
      CommandAlreadyRunning = {
        Type       = "Pass"
        ResultPath = "$.customMessage"
        Parameters = {
          "Message" = "CommandAlreadyRunning"
        },
        OutputPath = "$.customMessage",
        Next       = "Success"
      }
      Success = {
        Type = "Succeed"
      }
      HandleError = {
        Type = "Fail"
      }
    }
  })
}

resource "aws_iam_role" "sfn" {
  name               = "${local.resource_name}-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role_policy.json
  managed_policy_arns = [
    aws_iam_policy.sendcommand.arn,
    aws_iam_policy.dynamodb.arn,
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
  name   = "${local.resource_name}-sendcommand"
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
resource "aws_iam_policy" "dynamodb" {
  name   = "${local.resource_name}-dynamodb"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.dynamodb.json
}

data "aws_iam_policy_document" "dynamodb" {
  statement {
    actions = [
      "dynamodb:putItem",
      "dynamodb:deleteItem",
    ]
    effect = "Allow"
    resources = [
      aws_dynamodb_table.state.arn,
    ]
  }
}
