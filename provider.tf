terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  assume_role {
    role_arn     = "arn:aws:iam::123456789012:role/ROLE_NAME"
    session_name = "SESSION_NAME"
    external_id  = "EXTERNAL_ID"
  }
}

provider "aws" {
  alias = "root"
  assume_role {
    role_arn      = ""
    session_name  = ""
    external_id   = ""
  }
}
