provider "aws" {
  alias   = "virginia"
  profile = "terraform"
}

resource "aws_s3_bucket" "www_my_website" {
  bucket = var.aws_s3_bucket_www
  tags   = var.aws_s3_bucket_tags
}

resource "aws_s3_bucket" "my_website" {
  bucket = var.aws_s3_bucket
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

# Recurso para o certificado SSL no Certificate Manager
resource "aws_acm_certificate" "my_certificate" {
  domain_name               = var.aws_s3_bucket_www
  subject_alternative_names = ["${var.aws_s3_bucket}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "certificate to my website"
  }
  provider = aws.virginia
}
# resource "aws_acm_certificate_validation" "certificate_validation" {
#   certificate_arn = aws_acm_certificate.my_certificate.arn
# }

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

// Cloudfront
resource "aws_cloudfront_distribution" "my_distribution" {
  origin {
    domain_name = aws_s3_bucket.my_website.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    target_origin_id = "S3Origin"
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    acm_certificate_arn            = aws_acm_certificate.my_certificate.arn
    # acm_certificate_arn            = aws_acm_certificate_validation.certificate_validation.certificate_arn
  }
  aliases    = ["${var.aws_s3_bucket}"]
  depends_on = [aws_acm_certificate_validation.certificate_validation]
}

# Recurso para a distribuição CloudFront com www
resource "aws_cloudfront_distribution" "www_my_distribution" {
  origin {
    domain_name = aws_s3_bucket.www_my_website.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }
  enabled             = true
  default_root_object = "index.html"
  default_cache_behavior {
    target_origin_id = "S3Origin"
    allowed_methods  = ["HEAD", "GET"]
    cached_methods   = ["HEAD", "GET"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "redirect-to-https"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = false
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    acm_certificate_arn            = aws_acm_certificate.my_certificate.arn
    # acm_certificate_arn            = aws_acm_certificate_validation.certificate_validation.certificate_arn
  }
  aliases    = ["${var.aws_s3_bucket_www}"]
  depends_on = [aws_acm_certificate_validation.certificate_validation]
}

# Atualização dos registros A do Route53 para apontarem para as distribuições do CloudFront
resource "aws_route53_record" "my_record_to_cloudfront" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.aws_s3_bucket_www
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.www_my_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_my_distribution.hosted_zone_id
    evaluate_target_health = false
  }
  depends_on = [
    aws_cloudfront_distribution.www_my_distribution
  ]
}

resource "aws_route53_record" "my_record_to_cloudfront_no_www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.aws_s3_bucket
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.my_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.my_distribution.hosted_zone_id
    evaluate_target_health = false
  }
  depends_on = [
    aws_cloudfront_distribution.my_distribution
  ]
}
resource "aws_s3_object" "public_folder" {
  for_each     = fileset("public/", "*")
  bucket       = aws_s3_bucket.www_my_website.id
  key          = each.value
  source       = "public/${each.value}"
  etag         = filemd5("public/${each.value}")
  content_type = "text/html"
}

resource "null_resource" "cache_invalidation" {
  # prevent invalidating cache before new s3 file is uploaded
  depends_on = [
    aws_s3_object.public_folder
  ]
  for_each = fileset("${path.module}/public/", "**")
  triggers = {
    hash = filemd5("public/${each.value}")
  }
  provisioner "local-exec" {
    # sleep is necessary to prevent throttling when invalidating many files; a dynamic sleep time would be more reliable
    # possible way of dealing with parallelism (though would lose the indiviual triggers): https://discuss.hashicorp.com/t/specify-parallelism-for-null-resource/20884/2
    command = "sleep 1; aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.my_distribution.id} --paths '/${each.value}'"
  }
}

# resource "aws_route53_record" "my_additional_record" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = var.aws_s3_bucket
#   type    = "A"
#   alias {
#     name                   = aws_cloudfront_distribution.my_distribution.domain_name
#     zone_id                = aws_cloudfront_distribution.my_distribution.hosted_zone_id
#     evaluate_target_health = false
#   }
#   depends_on = [
#     aws_cloudfront_distribution.my_distribution
#   ]
# }
 
