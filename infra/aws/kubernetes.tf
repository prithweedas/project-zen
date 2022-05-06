# NOTE: update kubeconfig once eks is setup
data "external" "kubeconfig" {
  program = ["bash", "updatekubeconfig.sh", var.primary_region, aws_eks_cluster.eks.name, var.aws_profile]

  depends_on = [
    aws_eks_cluster.eks
  ]
}

resource "kubernetes_namespace" "prefect" {
  metadata {
    name = "${var.project_name}-prefect-namespace"
  }
}

locals {
  iam_serviceaccount_annotation = "eks.amazonaws.com/role-arn"
}

resource "kubernetes_service_account" "prefect_serviceaccount" {
  metadata {
    name      = "${var.project_name}-prefect-serviceaccount"
    namespace = kubernetes_namespace.prefect.id
  }

  depends_on = [
    data.external.kubeconfig
  ]

  lifecycle {
    # NOTE: we will annotate this later to avoid cycles
    ignore_changes = [metadata.0.annotations]
  }
}


# NOTE: OIDC setup to give pods access to AWS services

variable "prefect_agent_namespace" {
  type        = string
  description = "namespace where prefect agent will get deployed"
  default     = "default"
}

variable "prefect_agent_serviceaccount" {
  type        = string
  description = "serviceaccount for prefect agent"
  default     = "prefect"
}

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

  depends_on = [
    aws_eks_cluster.eks
  ]
}

data "aws_iam_policy_document" "prefect_s3_results_access" {
  statement {
    sid    = "VisualEditor0"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]

    resources = [join("", [aws_s3_bucket.flow_results.arn, "/*"])]
  }
}

resource "aws_iam_policy" "prefect_s3_results_access" {
  policy = data.aws_iam_policy_document.prefect_s3_results_access.json

  name        = "${var.project_name}-prefect-results-s3"
  path        = "/"
  description = "Policy to let Prefect store results in S3"

  depends_on = [
    aws_s3_bucket.flow_results
  ]
}


data "aws_iam_policy_document" "prefect_aws_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${kubernetes_namespace.prefect.metadata[0].name}:${kubernetes_service_account.prefect_serviceaccount.metadata[0].name}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}


resource "aws_iam_role" "prefect_aws_role" {
  assume_role_policy = data.aws_iam_policy_document.prefect_aws_policy.json
  name               = "${var.project_name}-prefect-aws-role"
  depends_on         = [aws_iam_openid_connect_provider.eks]
}

resource "aws_iam_role_policy_attachment" "prefect_aws_role" {
  role       = aws_iam_role.prefect_aws_role.name
  policy_arn = aws_iam_policy.prefect_s3_results_access.arn
}

output "prefect_aws_role" {
  value       = aws_iam_role.prefect_aws_role.name
  description = "IAM Role for prefect agent"
}

# NOTE: annotate service account with newly created role

resource "kubernetes_annotations" "prefect_serviceagent" {
  api_version = "v1"
  kind        = "ServiceAccount"
  metadata {
    name      = kubernetes_service_account.prefect_serviceaccount.metadata.0.name
    namespace = kubernetes_service_account.prefect_serviceaccount.metadata.0.namespace
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.prefect_aws_role.arn
  }
}


# NOTE: Roles and RoleBindings for prefect agent
