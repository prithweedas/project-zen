# NOTE: Roles and Policies for EKS

locals {
  eks_name = "${var.project_name}-eks-role"
}


resource "aws_iam_role" "eks" {
  name = local.eks_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
  POLICY

  tags = {
    "Name" = local.eks_name
  }
}

resource "aws_iam_role_policy_attachment" "eks" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

output "eks_iam_role" {
  value       = aws_iam_role.eks.name
  description = "IAM role for eks cluster"
}

# NOTE: EKS

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version to use for EKS"
  default     = "1.21"
}

resource "aws_eks_cluster" "eks" {
  name     = local.eks_cluster_name
  role_arn = aws_iam_role.eks.arn
  version  = var.kubernetes_version

  vpc_config {

    # NOTE: we can use a private endpoint with bastion host or VPN
    endpoint_private_access = false
    endpoint_public_access  = true

    subnet_ids = concat(
      [for key, value in aws_subnet.public : value.id],
      [for key, value in aws_subnet.private : value.id]
    )
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks
  ]
}

locals {
  eks_oidc_url = aws_eks_cluster.eks.identity[0]["oidc"][0]["issuer"]
}

output "eks_cluster" {
  value = aws_eks_cluster.eks.name
}

output "eks_oidc_url" {
  value       = local.eks_oidc_url
  sensitive   = true
  description = "Open ID connect provider URL"
}


# NOTE: Roles and Policies for EKS Node group

locals {
  eks_nodes_name = "${var.project_name}-eks-nodes-role"
}

locals {
  eks_nodes_policy_arns = {
    "worker_node"   = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "ecr_read_only" = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "eks_cni"       = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }
}

resource "aws_iam_role" "eks_nodes" {
  name = local.eks_nodes_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
  POLICY

  tags = {
    "Name" = local.eks_nodes_name
  }
}


resource "aws_iam_role_policy_attachment" "eks_nodes" {
  for_each   = local.eks_nodes_policy_arns
  role       = aws_iam_role.eks_nodes.name
  policy_arn = each.value
}


output "eks_node_iam_role" {
  value       = aws_iam_role.eks_nodes.name
  description = "IAM role for eks node group"
}

# NOTE: EKS Node group

locals {
  node_group_name = "${var.project_name}-eks-node-group"
}

resource "aws_eks_node_group" "node" {
  cluster_name = aws_eks_cluster.eks.name

  node_group_name = local.node_group_name

  node_role_arn = aws_iam_role.eks_nodes.arn

  subnet_ids = [for key, value in aws_subnet.private : value.id]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }

  ami_type             = "AL2_x86_64"
  capacity_type        = "ON_DEMAND"
  disk_size            = 20
  force_update_version = false
  instance_types       = ["t3.small"]
  labels = {
    role = local.node_group_name
  }

  tags = {
    "Name" = aws_eks_cluster.eks.name
  }

  depends_on = [aws_iam_role_policy_attachment.eks_nodes]
}
