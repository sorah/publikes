data "aws_cloudfront_origin_request_policy" "Managed-AllViewerExceptHostHeader" {
  name = "Managed-AllViewerExceptHostHeader"
}
data "aws_cloudfront_origin_request_policy" "Managed-CORS-S3Origin" {
  name = "Managed-CORS-S3Origin"
}
data "aws_cloudfront_cache_policy" "Managed-CachingDisabled" {
  name = "Managed-CachingDisabled"
}
#data "aws_cloudfront_cache_policy" "Managed-UseOriginCacheControlHeaders" {
#  name = "Managed-UseOriginCacheControlHeaders"
#}
data "aws_cloudfront_cache_policy" "Managed-CachingOptimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "public" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "publikes/${var.name_prefix}"
  aliases         = [var.app_domain]

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  logging_config {
    include_cookies = false
    bucket          = var.cloudfront_log_bucket
    prefix          = var.cloudfront_log_prefix
  }

  origin {
    origin_id   = "s3public-ui"
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_path = "/ui"
  }
  origin {
    origin_id   = "s3public-data"
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
  }

  default_root_object = "index.html"

  ordered_cache_behavior {
    path_pattern = "/data/*"

    allowed_methods = ["GET", "HEAD", "OPTIONS", ]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id         = "s3public-data"
    cache_policy_id          = "83da9c7e-98b4-4e11-a168-04f0df8e2c65" # data.aws_cloudfront_cache_policy.Managed-UseOriginCacheControlHeaders.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.Managed-CORS-S3Origin.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS", ]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id         = "s3public-ui"
    cache_policy_id          = data.aws_cloudfront_cache_policy.Managed-CachingOptimized.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.Managed-CORS-S3Origin.id

    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name      = "${var.name_prefix}"
    Component = "cloudfront"
  }
}
