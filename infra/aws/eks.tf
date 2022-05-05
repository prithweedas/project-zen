# NOTE: Roles and Polycies for EKS

resource "aws_iam_role" "eks" {
  name = "${var.project_name}-eks-role"

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
    "Name" = "${var.project_name}-eks-role"
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
