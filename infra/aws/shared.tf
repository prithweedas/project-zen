variable "project_name" {
  type        = string
  description = "Name of this project. This will be used to tag resources uniquely"
}

locals {
  eks_cluster_name = "${var.project_name}-eks-cluster"
}
