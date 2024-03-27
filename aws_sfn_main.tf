
variable sfn_name {
  type        = string
  default     = "SSO-Group-Assigner"
  description = "The Name of the main StepFunction"
}


resource "aws_sfn_state_machine" "main" {
  name     = var.sfn_name
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "StartAt": "Pass",
  "States": {
    "Pass": {
      "Comment": "A Pass state passes its input to its output, without performing work. They can also generate static JSON output, or transform JSON input using filters and pass the transformed data to the next state. Pass states are useful when constructing and debugging state machines.",
      "Type": "Pass",
      "Next": "RequestRouter"
    },
    "RequestRouter": {
      "Comment": "A Choice state adds branching logic to a state machine. Choice rules can implement many different comparison operators, and rules can be combined using And, Or, and Not",
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.AuditMode",
          "BooleanEquals": true,
          "Next": "Yes"
        },
        {
          "Variable": "$.AuditMode",
          "BooleanEquals": false,
          "Next": "No"
        }
      ],
      "Default": "Yes"
    },
    "Yes": {
      "Type": "Pass",
      "Next": "Get-Timestamp"
    },
    "Get-Timestamp": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:123412341234:function:Stepfunction-Helpers-Timestamp-Converter:$LATEST",
        "Payload": {
          "ts.$": "$$.State.EnteredTime"
        }
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
      "Next": "ListInstances",
      "ResultSelector": {
        "AccessGrantedAt.$": "$.Payload"
      },
      "ResultPath": "$.Logging"
    },
    "ListInstances": {
      "Type": "Task",
      "Next": "GetUserId",
      "Parameters": {},
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:listInstances",
      "ResultSelector": {
        "InstanceArn.$": "$.Instances[0].InstanceArn"
      },
      "ResultPath": "$.InstancesResult"
    },
    "GetUserId": {
      "Type": "Task",
      "Next": "Wait 3 sec",
      "Parameters": {
        "AlternateIdentifier": {
          "UniqueAttribute": {
            "AttributePath": "emails.value",
            "AttributeValue.$": "$.IDP_Email"
          }
        },
        "IdentityStoreId": "d-xxxxxx"
      },
      "Resource": "arn:aws:states:::aws-sdk:identitystore:getUserId",
      "ResultSelector": {
        "UserId.$": "$.UserId"
      },
      "ResultPath": "$.GetUserIdResult"
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
    "No": {
      "Type": "Fail",
      "Cause": "Not Hello World"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}