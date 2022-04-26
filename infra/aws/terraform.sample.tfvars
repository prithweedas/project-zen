project_name = "value"

aws_profile = "value"

primary_region = "value"

vpc_cidr_block = "value"

private_subnets = {
  "private-us-east-1a" = {
    cidr_block        = "value"
    availability_zone = "us-east-1a"
  }

  "private-us-east-1b" = {
    cidr_block        = "value"
    availability_zone = "us-east-1b"
  }
}

public_subnets = {
  "public-us-east-1a" = {
    cidr_block        = "value"
    availability_zone = "us-east-1a"
  }
  "public-us-east-1b" = {
    cidr_block        = "value"
    availability_zone = "us-east-1b"
  }
}

cluster_name = "zen"
