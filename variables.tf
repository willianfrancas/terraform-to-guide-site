variable "aws_region" {
  description = "cheaper region to use us-east-1"
  type        = string
  default     = "us-east-1"
}

variable "aws_s3_bucket_www" {
  description = "s3 bucket name"
  type        = string
  default     = "www.banana.com.br"
}

variable "aws_s3_bucket_tags" {
  description = "tags to identify s3 bucket"
  type        = map(string)
  default = {
    Name        = "My Terraform bucket",
    Environment = "Dev",
    Managedby   = "Terraform",
  }
}

