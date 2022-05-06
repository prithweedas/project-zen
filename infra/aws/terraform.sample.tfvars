project_name = "value"

aws_profile = "value"

primary_region = "value"

vpc_cidr_block = "value"

private_subnets = {
  "private-ap-south-1a" = {
    cidr_block        = "value"
    availability_zone = "ap-south-1a"
  }

  "private-ap-south-1b" = {
    cidr_block        = "value"
    availability_zone = "ap-south-1b"
  }
}

public_subnets = {
  "public-ap-south-1a" = {
    cidr_block        = "value"
    availability_zone = "ap-south-1a"
  }
  "public-ap-south-1b" = {
    cidr_block        = "value"
    availability_zone = "ap-south-1b"
  }
}

kubernetes_version = "1.21"

prefect_agent_namespace = "value"

prefect_agent_serviceaccount = "value"
