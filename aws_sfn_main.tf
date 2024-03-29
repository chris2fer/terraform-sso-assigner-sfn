
variable sfn_name {
  type        = string
  default     = "SSO-Group-Assigner"
  description = "The Name of the main StepFunction"
}


resource "aws_sfn_state_machine" "main" {
  name      = var.sfn_name
  type      = "STANDARD"
  role_arn  = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "StartAt": "Pass",
  "States": {
    "Pass": {
      "Comment": "A Pass state passes its input to its output, without performing work. They can also generate static JSON output, or transform JSON input using filters and pass the transformed data to the next state. Pass states are useful when constructing and debugging state machines.",
      "Type": "Pass",
      "Next": "ListInstances"
    },
    "ListInstances": {
      "Type": "Task",
      "Next": "ResolveAccountID",
      "Parameters": {},
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:listInstances",
      "ResultSelector": {
        "InstanceArn.$": "$.Instances[0].InstanceArn"
      },
      "ResultPath": "$.InstancesResult"
    },
    "ResolveAccountID": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:078673572457:function:SSO-Assigner-ResolveAccount:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "ResolvePermissionSet"
    },
    "ResolvePermissionSet": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:078673572457:function:SSO-Assigner-ResolvePSet:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException"
          ],
          "IntervalSeconds": 1,
          "MaxAttempts": 3,
          "BackoffRate": 2
        }
      ],
      "Next": "Wait 3 sec"
    },
    "Wait 3 sec": {
      "Comment": "A Wait state delays the state machine from continuing for a specified time.",
      "Type": "Wait",
      "Seconds": 3,
      "Next": "CreateAccountAssignment"
    },
    "CreateAccountAssignment": {
      "Type": "Task",
      "Next": "CreateLogStream",
      "Parameters": {
        "InstanceArn.$": "$.InstancesResult.InstanceArn",
        "PermissionSetArn.$": "$.PermissionSetArn",
        "PrincipalId.$": "$.GetUserIdResult.UserId",
        "PrincipalType": "USER",
        "TargetId.$": "$.AccountId",
        "TargetType": "AWS_ACCOUNT"
      },
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:createAccountAssignment",
      "ResultPath": null
    },
    "CreateLogStream": {
      "Type": "Task",
      "Next": "PutLogEvents",
      "Parameters": {
        "LogGroupName": "/tf/pce/just-in-time-access/access-grants",
        "LogStreamName": "2024/03/21"
      },
      "Resource": "arn:aws:states:::aws-sdk:cloudwatchlogs:createLogStream",
      "Catch": [
        {
          "ErrorEquals": [
            "States.TaskFailed"
          ],
          "Next": "PutLogEvents",
          "ResultPath": null
        }
      ],
      "ResultPath": null
    },
    "PutLogEvents": {
      "Type": "Task",
      "Next": "Wait",
      "Parameters": {
        "LogEvents": [
          {
            "Message": "MyData",
            "Timestamp.$": "$.Logging.AccessGrantedAt"
          }
        ],
        "LogGroupName": "/tf/pce/just-in-time-access/access-grants",
        "LogStreamName": "2024/03/21"
      },
      "Resource": "arn:aws:states:::aws-sdk:cloudwatchlogs:putLogEvents",
      "ResultPath": null
    },
    "Wait": {
      "Type": "Wait",
      "Next": "DeleteAccountAssignment",
      "SecondsPath": "$.AccessTimeSeconds"
    },
    "DeleteAccountAssignment": {
      "Type": "Task",
      "Next": "Success",
      "Parameters": {
        "InstanceArn.$": "$.InstancesResult.InstanceArn",
        "PermissionSetArn.$": "$.PermissionSetArn",
        "PrincipalId.$": "$.GetUserIdResult.UserId",
        "PrincipalType": "USER",
        "TargetId.$": "$.AccountId",
        "TargetType": "AWS_ACCOUNT"
      },
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:deleteAccountAssignment"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}