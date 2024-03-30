

resource "aws_iam_role" "pset_resolver_lambda" {
  name               = "SSO-Assigner-PSet-Resolver-Lambda"
  path               = "/app/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  inline_policy {
    name = "inline_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "sso:*"
            "logs:*",
            "cloudwatch:*"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
}

data "archive_file" "pset_resolver_lambda" {
  type        = "zip"
  source_file = "./src/pset_resolver.py"
  output_path = "./src/pset_resolver_payload.zip"
}

resource "aws_lambda_function" "pset_resolver" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "./src/pset_resolver_payload.zip"
  function_name = "SSO-Assigner-PSet-Resolver"
  role          = aws_iam_role.pset_resolver_lambda.arn
  handler       = "pset_resolver.lambda_handler"
  architectures = ["arm64"]

  source_code_hash = data.archive_file.pset_resolver_lambda.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
      foo = "bar"
    }
  }
}