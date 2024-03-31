resource "aws_cloudwatch_log_group" "sso" {
  name = var.cloudwatch_log_group_name

  tags = {
    Environment = "production"
    Application = "Identity-Center-Automation"
  }
}