provider "aws" {
  region  = "us-east-1"
  profile = "terraform"
}

resource "aws_s3_bucket" "www-willianfrancas-com-br" {
  bucket = "www-willianfrancas-com-br"
  tags = {
    Name        = "My Terraform bucket with www"
    Environment = "Dev"
    Managedby   = "Terraform"
  }
}

resource "aws_s3_bucket" "willianfrancas-com-br" {
  bucket = "willianfrancas-com-br"
  tags = {
    Name        = "My Terraform bucket without www"
    Environment = "Dev"
    Managedby   = "Terraform"
  }
}

resource "aws_s3_bucket_website_configuration" "www-willianfrancas-com-br" {
  bucket = aws_s3_bucket.www-willianfrancas-com-br.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }  
}

resource "aws_s3_bucket_public_access_block" "www-willianfrancas-com-br" {
  bucket                  = aws_s3_bucket.www-willianfrancas-com-br.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.www-willianfrancas-com-br.id
  policy = data.aws_iam_policy_document.allow_access.json
}

data "aws_iam_policy_document" "allow_access" {
  version = "2012-10-17"
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.www-willianfrancas-com-br.arn}/*"
    ]
  }
}
