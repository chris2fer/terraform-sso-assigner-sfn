variable cloudwatch_log_group_name {
  type        = string
  default     = "/sso/automation/group-assigner/sfn"
  description = "The Location of the Cloudwawtch logs for the step function logs"
}

variable iam_for_sfn_name {
  type        = string
  default     = "StepFunction-Role"
  description = "The IAM Role for SSO Group Assigner SFN"
}

variable sfn_name {
  type        = string
  default     = "SSO-Group-Assigner"
  description = "The Name of the main StepFunction"
}