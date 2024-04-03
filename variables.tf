terraform {
  cloud {
    organization = "willianfrancas"

    workspaces {
      name = "terraform_guide"
    }
  }
}

variable "aws_region" {
  description = "cheaper region to use us-east-1"
  type        = string
  default     = "us-east-1"
}

variable "aws_s3_bucket" {
  description = "s3 bucket name"
  type        = string
  default     = "my-website.com.br"
}

variable "aws_s3_bucket_www" {
  description = "s3 bucket name"
  type        = string
  default     = "www.my-website.com.br"
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

variable "aws_cloudfront_tags" {
  description = "tags to cloudfront by terraform"
  type        = map(string)
  default = {
    Name      = "My cloudfront create by terraform"
    Managedby = "Terraform"
  }
}
