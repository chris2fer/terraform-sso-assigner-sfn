data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "account_resolver_lambda" {
  name               = "SSO-Assigner-Account-Resolver-Lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "archive_file" "account_resolver_lambda" {
  type        = "zip"
  source_file = "./src/account_resolver.py"
  output_path = "./src/account_resolver_payload.zip"
}

resource "aws_lambda_function" "account_resolver" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "account_resolver_payload.zip"
  function_name = "SSO-Assigner-Account-Resolver"
  role          = aws_iam_role.account_resolver_lambda.arn
  handler       = "account_resolver.lambda_handler"
  architectures = ["arm64"]

  source_code_hash = data.archive_file.account_resolver_lambda.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
      foo = "bar"
    }
  }
}