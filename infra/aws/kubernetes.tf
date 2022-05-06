# NOTE: OIDC setup to give pods access to AWS services

data "external" "thumbprint" {
  program = ["bash", "thumbprint.sh", var.primary_region]
}

output "oidc_thumbprint" {
  value     = data.external.thumbprint.result.data
  sensitive = true
}


resource "aws_iam_openid_connect_provider" "eks" {
  url = local.eks_oidc_url

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.external.thumbprint.result.data]

  tags = {
    "Name" = "${var.project_name}-oidc"
  }
}

