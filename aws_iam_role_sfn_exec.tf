variable iam_for_sfn_name {
  type        = string
  default     = "StepFunction-Role"
  description = "The IAM Role for SSO Group Assigner SFN"
}


resource aws_iam_role iam_for_sfn {
    name = var.iam_for_sfn_name
}