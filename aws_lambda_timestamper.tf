
resource "aws_iam_role" "timestamper_lambda" {
  name               = "SSO-Assigner-Timestamp-Lambda"
  path               = "/app/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  inline_policy {
    name = "inline_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
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

data "archive_file" "timestamper_lambda" {
  type        = "zip"
  source_file = "./src/timestamper.py"
  output_path = "./src/timestamper_payload.zip"
}

resource "aws_lambda_function" "timestamper" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "./src/timestamper_payload.zip"
  function_name = "SSO-Timestamper"
  role          = aws_iam_role.timestamper_lambda.arn
  handler       = "timestamper.lambda_handler"
  architectures = ["arm64"]

  source_code_hash = data.archive_file.timestamper_lambda.output_base64sha256

  runtime = "python3.12"

  environment {
    variables = {
      foo = "bar"
    }
  }
}