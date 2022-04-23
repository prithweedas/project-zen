# NOTE: Configures terraform providers, i.e. aws

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.10"
    }
  }
}


provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
}


# NOTE: variables

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
  default     = "us-east-1"
}


variable "aws_profile" {
  type        = string
  description = "AWS profile to use"
}
