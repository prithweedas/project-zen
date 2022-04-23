# NOTE: VPC

resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  # NOTE: Needed by EKS, More details -
  # https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_classiclink               = false
  enable_classiclink_dns_support   = false
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for VPC"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC id created for this project"
}
