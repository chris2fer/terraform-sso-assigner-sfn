
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
      "Next": "Pass (1)",
      "InputPath": "$.detail.requestParameters",
      "Parameters": {
        "groupName.$": "$.displayName",
        "splitter": "_"
      }
    },
    "Pass (1)": {
      "Type": "Pass",
      "Next": "ListInstances",
      "Parameters": {
        "pvf_tag.$": "States.Format('\\{\"Key\": \"PVF_ID\", \"Value\": \"{}\"\\}',States.ArrayGetItem(States.StringSplit($.groupName, $.splitter),2))",
        "pvfx_tag.$": "States.Format('\\{\"Key\": \"PVFXID\", \"Value\": \"{}\"\\}',States.ArrayGetItem(States.StringSplit($.groupName, $.splitter),4))"
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
      "OutputPath": "$.Payload",
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
      "Next": "ResolveAccountID"
    },
    "ResolveAccountID": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
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
      "Next": "Wait 3 sec"
    },
    "Wait 3 sec": {
      "Comment": "A Wait state delays the state machine from continuing for a specified time.",
      "Type": "Wait",
      "Seconds": 3,
      "Next": "CreateLogStream"
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
      "Next": "Success",
      "SecondsPath": "$.AccessTimeSeconds"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
EOF
}