locals {
  s3_bucket_name = "${var.project_name}-flow-results"
}

resource "aws_s3_bucket" "flow_results" {
  bucket = local.s3_bucket_name

  tags = {
    "Name" = local.s3_bucket_name
  }
}

resource "aws_s3_bucket_acl" "flow_results_acl" {
  bucket = aws_s3_bucket.flow_results.id
  acl    = "private"
}


output "s3_bucket" {
  value       = aws_s3_bucket.flow_results.bucket
  description = "S3 bucket to store flow results"
}
