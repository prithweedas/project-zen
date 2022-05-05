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
    "Name"                                            = "${var.project_name}-${each.key}-subnet"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }
}

output "public_subnet_ids" {
  value = {
    for key, value in aws_subnet.public : key => value.id
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    "Name"                                            = "${var.project_name}-${each.key}-subnet"
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }
}

output "private_subnet_ids" {
  value = {
    for key, value in aws_subnet.private : key => value.id
  }
}

# NOTE: Elastic IPs

resource "aws_eip" "eips" {
  for_each = aws_subnet.public

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    "Name" = "${var.project_name}-${each.key}-eip"
  }
}

output "elastic_ips" {
  value = {
    for key, value in aws_eip.eips : key => value.id
  }

  description = "Elastic IPs for NAT Gateways"
}

# NOTE: NAT Gateways


resource "aws_nat_gateway" "public" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.eips[each.key].id

  subnet_id = each.value.id

  tags = {
    "Name" = "${var.project_name}-${each.key}-nat-gateway"
  }
}

output "nat_gateways" {
  value = {
    for key, value in aws_nat_gateway.public : key => value.id
  }

  description = "NAT Gateways"
}

# NOTE: Route tables

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    "Name" = "${var.project_name}-public-route-table"
  }
}


resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.public[replace(each.key, "private", "public")].id
  }

  tags = {
    "Name" = "${var.project_name}-${each.key}-route-table"
  }
}

# NOTE: Route table associations

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
