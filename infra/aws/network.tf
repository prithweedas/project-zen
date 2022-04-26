# NOTE: VPC

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for VPC"
}

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
    "Name" = "${var.project_name}-vpc"
  }
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC id created for this project"
}


# NOTE: Internet Gateway

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.project_name}-igw"
  }
}

output "igw_id" {
  value       = aws_internet_gateway.main.id
  description = "Internet Gateway id"
}

# NOTE: Subnets

variable "public_subnets" {
  type = map(object(
    {
      cidr_block        = string
      availability_zone = string
    }
  ))

  validation {
    condition     = length(var.public_subnets) >= 2
    error_message = "Must be atleast 2 subnets in 2 different AZs."
  }
}

variable "private_subnets" {
  type = map(object(
    {
      cidr_block        = string
      availability_zone = string
    }
  ))

  validation {
    condition     = length(var.private_subnets) >= 2
    error_message = "Must be atleast 2 subnets in 2 different AZs."
  }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "${var.project_name}-${each.key}-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

output "public_subnet_ids" {
  value = {
    for k, v in aws_subnet.public : k => v.id
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    "Name"                                      = "${var.project_name}-${each.key}-subnet"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

output "private_subnet_ids" {
  value = {
    for k, v in aws_subnet.private : k => v.id
  }
}
