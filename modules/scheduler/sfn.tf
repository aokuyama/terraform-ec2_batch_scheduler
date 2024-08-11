resource "aws_sfn_state_machine" "send_command_to_ec2" {
  name     = "sendcommand-to-ec2"
  role_arn = aws_iam_role.sfn.arn
  definition = jsonencode({
    StartAt = "CheckLockCommandId",
    States = {
      CheckLockCommandId = {
        Type = "Choice"
        Choices = [
          {
            Variable  = "$.commandId"
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
            "commandId" = {
              "S.$" = "$.commandId"
            }
          }
          ConditionExpression = "attribute_not_exists(commandId)"
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
            Variable  = "$.commandId"
            IsPresent = true,
            Next      = "UnlockCommand"
          }
        ]
        Default = "Success"
      }
      UnlockCommand = {
        Type     = "Task",
        Resource = "arn:aws:states:::dynamodb:deleteItem",
        Parameters = {
          TableName = aws_dynamodb_table.state.name
          Key = {
            "commandId" = {
              "S.$" = "$.commandId"
            }
          }
        }
        Next = "Success"
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
      Success = {
        Type = "Succeed"
      }
      HandleError = {
        Type = "Fail"
      }
      CommandAlreadyRunning = {
        Type = "Fail"
      }
    }
  })
}

resource "aws_iam_role" "sfn" {
  name               = "${var.env}-scheduler-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume_role_policy.json
  managed_policy_arns = [
    aws_iam_policy.sendcommand.arn,
    aws_iam_policy.put_dynamodb.arn,
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
resource "aws_iam_policy" "put_dynamodb" {
  name   = "${var.env}-scheduler-put_dynamodb"
  path   = "/service-role/"
  policy = data.aws_iam_policy_document.put_dynamodb.json
}

data "aws_iam_policy_document" "put_dynamodb" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:deleteItem",
    ]
    effect = "Allow"
    resources = [
      aws_dynamodb_table.state.arn,
    ]
  }
}
