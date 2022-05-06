# NOTE: variables

variable "primary_region" {
  type        = string
  description = "Primary AWS region"
  default     = "us-east-1"
}


variable "aws_profile" {
  type        = string
  description = "AWS profile to use"
  default     = "default"
}

# NOTE: Configures terraform providers, i.e. aws

terraform {


  backend "s3" {
    profile = "default"
    bucket  = "vested-env-files"
    key     = "terraform/zen.tfstate"
    region  = "us-east-1"
  }


  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.10"
    }

    external = {
      source  = "hashicorp/external"
      version = "2.2.2"
    }
  }
}


provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
}
