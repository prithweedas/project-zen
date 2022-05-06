variable "project_name" {
  type        = string
  description = "Name of this project. This will be used to tag resources uniquely"
}

locals {
  eks_cluster_name = "${var.project_name}-eks-cluster"
}

output "region" {
  value       = var.primary_region
  description = "Region"
}

variable "prefect_api_key" {
  type        = string
  description = "API key for prefect cloud"
}
