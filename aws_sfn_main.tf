

resource "aws_sfn_state_machine" "main" {
  name      = var.sfn_name
  type      = "STANDARD"
  role_arn  = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "StartAt": "Scrub-Event",
  "States": {
    "Scrub-Event": {
      "Comment": "A Pass state passes its input to its output, without performing work. They can also generate static JSON output, or transform JSON input using filters and pass the transformed data to the next state. Pass states are useful when constructing and debugging state machines.",
      "Type": "Pass",
      "Next": "Transform-State",
      "InputPath": "$.detail.responseElements",
      "Parameters": {
        "groupName.$": "$.group.displayName",
        "groupId.$": "$.group.groupId",
        "splitter": "_"
      }
    },
    "Transform-State": {
      "Type": "Pass",
      "Next": "ListInstances",
      "Parameters": {
        "pvf_tag.$": "States.Format('\\{\"Key\": \"PVF_ID\", \"Value\": \"{}\"\\}',States.ArrayGetItem(States.StringSplit($.groupName, $.splitter),2))",
        "pvfx_tag.$": "States.Format('\\{\"Key\": \"PVFXID\", \"Value\": \"{}\"\\}',States.ArrayGetItem(States.StringSplit($.groupName, $.splitter),4))",
        "group": {
          "displayName.$": "$.groupName",
          "guid.$": "$.groupId"
        }
      }
    },
    "ListInstances": {
      "Type": "Task",
      "Next": "ResolvePermissionSet",
      "Parameters": {},
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:listInstances",
      "ResultSelector": {
        "InstanceArn.$": "$.Instances[0].InstanceArn"
      },
      "ResultPath": "$.InstancesResult"
    },
    "ResolvePermissionSet": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:078673572457:function:SSO-Assigner-PSet-Resolver"
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
      "Next": "ResolveAccountID",
      "ResultPath": "$.PermissionSet",
      "ResultSelector": {
        "PermissionSetArn.$": "$.Payload"
      }
    },
    "ResolveAccountID": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:078673572457:function:SSO-Assigner-Account-Resolver"
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
      "Next": "CreateAccountAssignment",
      "ResultPath": "$.Account",
      "ResultSelector": {
        "Id.$": "$.Payload.Id"
      }
    },
    "CreateAccountAssignment": {
      "Type": "Task",
      "Next": "Wait 3 sec",
      "Parameters": {
        "InstanceArn.$": "$.InstancesResult.InstanceArn",
        "PermissionSetArn.$": "$.PermissionSet.PermissionSetArn",
        "PrincipalId.$": "$.group.guid",
        "PrincipalType": "GROUP",
        "TargetId.$": "$.Account.Id",
        "TargetType": "AWS_ACCOUNT"
      },
      "Resource": "arn:aws:states:::aws-sdk:ssoadmin:createAccountAssignment"
    },
    "Wait 3 sec": {
      "Comment": "A Wait state delays the state machine from continuing for a specified time.",
      "Type": "Wait",
      "Seconds": 3,
      "Next": "Get-Timestamp"
    },
    "Get-Timestamp": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload": {
          "ts.$": "$$.State.EnteredTime"
        },
        "FunctionName": "${aws_lambda_function.timestamper.arn}"
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
      "Next": "PutLogEvents",
      "ResultSelector": {
        "Timestamp.$": "$.Payload"
      },
      "ResultPath": "$.Logging"
    },
    "PutLogEvents": {
      "Type": "Task",
      "Next": "Success",
      "Parameters": {
        "LogEvents": [
          {
            "Message": "MyData",
            "Timestamp.$": "$.Logging.Timestamp"
          }
        ],
        "LogGroupName": "${var.cloudwatch_log_group_name}",
        "LogStreamName": "2024/03/30"
      },
      "Resource": "arn:aws:states:::aws-sdk:cloudwatchlogs:putLogEvents",
      "ResultPath": null,
      "Catch": [
        {
          "ErrorEquals": [
            "States.TaskFailed"
          ],
          "Next": "CreateLogStream"
        }
      ]
    },
    "CreateLogStream": {
      "Type": "Task",
      "Next": "Success",
      "Parameters": {
        "LogGroupName": "/sso/automation/group-assigner/sfn",
        "LogStreamName": "2024/03/30"
      },
      "Resource": "arn:aws:states:::aws-sdk:cloudwatchlogs:createLogStream",
      "ResultPath": null
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}