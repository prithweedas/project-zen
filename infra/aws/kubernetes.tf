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
  prefect_k8s_namespace = kubernetes_namespace.prefect.metadata.0.name
}

resource "kubernetes_service_account" "prefect_serviceaccount" {
  metadata {
    name      = "${var.project_name}-prefect-serviceaccount"
    namespace = local.prefect_k8s_namespace
  }

  depends_on = [
    data.external.kubeconfig
  ]

  lifecycle {
    # NOTE: we will annotate this later to avoid cycles
    ignore_changes = [metadata.0.annotations]
  }
}

locals {
  prefect_k8s_serviceaccount = kubernetes_service_account.prefect_serviceaccount.metadata.0.name
}


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
      values   = ["system:serviceaccount:${local.prefect_k8s_namespace}:${local.prefect_k8s_serviceaccount}"]
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
    name      = local.prefect_k8s_serviceaccount
    namespace = local.prefect_k8s_namespace
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.prefect_aws_role.arn
  }
}


# NOTE: Roles and RoleBindings for prefect agent

resource "kubernetes_role" "prefect_agent" {
  metadata {
    name      = "${var.project_name}-prefect-k8s-role"
    namespace = local.prefect_k8s_namespace
  }

  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["*"]
  }

  rule {
    api_groups = [""]
    resources  = ["events", "pods"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "prefect_agent" {
  metadata {
    name      = "${var.project_name}-prefect-k8s-rolebinding"
    namespace = local.prefect_k8s_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.prefect_agent.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.prefect_k8s_serviceaccount
    namespace = local.prefect_k8s_namespace
  }
}

# NOTE: Deployment for prefect agent

resource "kubernetes_deployment" "prefect_agent" {
  wait_for_rollout = false
  metadata {
    generate_name = "${var.project_name}-prefect-agent"
    labels = {
      "name" = "prefect-agent"
    }
    namespace = local.prefect_k8s_namespace
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        "name" = "prefect-agent"
      }
    }

    template {
      metadata {
        labels = {
          "name" = "prefect-agent"
        }
      }
      spec {
        service_account_name = local.prefect_k8s_serviceaccount
        container {
          name              = "agent"
          image             = "prefecthq/prefect:1.2.0-python3.9"
          image_pull_policy = "Always"
          liveness_probe {
            failure_threshold = 2
            http_get {
              path = "/api/health"
              port = 8080
            }
            initial_delay_seconds = 40
            period_seconds        = 40
          }

          args = ["prefect agent kubernetes start"]

          command = ["/bin/bash", "-c"]

          env {
            name  = "PREFECT__CLOUD__AGENT__AUTH_TOKEN"
            value = var.prefect_api_key
          }

          env {
            name  = "PREFECT__CLOUD__API"
            value = "https://api.prefect.io"
          }

          env {
            name  = "NAMESPACE"
            value = local.prefect_k8s_namespace
          }

          env {
            name  = "IMAGE_PULL_SECRETS"
            value = ""
          }

          env {
            name  = "PREFECT__CLOUD__AGENT__LABELS"
            value = "['project-zen']"
          }

          env {
            name  = "JOB_MEM_REQUEST"
            value = ""
          }
          env {
            name  = "JOB_CPU_REQUEST"
            value = ""
          }

          env {
            name  = "JOB_CPU_LIMIT"
            value = ""
          }

          env {
            name  = "IMAGE_PULL_POLICY"
            value = ""
          }

          env {
            # NOTE: in future we may need to use a different service account for Jobs
            name  = "SERVICE_ACCOUNT_NAME"
            value = local.prefect_k8s_serviceaccount
          }

          env {
            name  = "PREFECT__BACKEND"
            value = "cloud"
          }

          env {
            name  = "PREFECT__CLOUD__AGENT__AGENT_ADDRESS"
            value = "http://:8080"
          }

          env {
            name  = "PREFECT__CLOUD__API_KEY"
            value = var.prefect_api_key
          }
          env {
            name  = "PREFECT__CLOUD__TENANT_ID"
            value = ""
          }
        }
      }
    }
  }
}
