

resource aws_iam_role iam_for_sfn {
    name  = var.iam_for_sfn_name
    path  = "/app/"
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "states.amazonaws.com"
          }
        },
      ]
  })

  inline_policy {
    name = "inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "sso:*",
            "organizations:List*",
            "organizations:Describe*",
            "lambda:InvokeFunction",
            "logs:*",
            "cloudwatch:*",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}
