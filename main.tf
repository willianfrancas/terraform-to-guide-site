provider "aws" {
  region  = var.aws_region
  profile = "terraform"
}

resource "aws_s3_bucket" "www_my_website" {
  bucket = var.aws_s3_bucket_www
  tags   = var.aws_s3_bucket_tags
}

resource "aws_s3_bucket_website_configuration" "www_my_website" {
  bucket = var.aws_s3_bucket_www
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "www_my_website" {
  bucket                  = aws_s3_bucket.www_my_website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.www_my_website.id
  policy = data.aws_iam_policy_document.allow_access.json

  depends_on = [
    aws_s3_bucket_public_access_block.www_my_website
  ]
}

data "aws_iam_policy_document" "allow_access" {
  version = "2012-10-17"
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.www_my_website.arn,
      "${aws_s3_bucket.www_my_website.arn}/*"
    ]
  }
}

resource "aws_route53_zone" "primary" {
  name = aws_s3_bucket.www_my_website.id
}

resource "aws_route53_record" "my_record_to_s3" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = aws_s3_bucket_website_configuration.www_my_website.id
  type    = "A"
  alias {
    name                   = aws_s3_bucket_website_configuration.www_my_website.website_domain
    zone_id                = aws_s3_bucket.www_my_website.hosted_zone_id
    evaluate_target_health = false
  }
  depends_on = [
    aws_s3_bucket_website_configuration.www_my_website
  ]
}

