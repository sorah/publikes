data "aws_cloudfront_origin_request_policy" "Managed-CORS-S3Origin" {
  name = "Managed-CORS-S3Origin"
}
data "aws_cloudfront_cache_policy" "Managed-CachingDisabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "Managed-CachingOptimized" {
  name = "Managed-CachingOptimized"
}

# NOTE: UseOriginCacheControlHeaders includes Host header forwarding which we don't want to.
#data "aws_cloudfront_cache_policy" "UseOriginCacheControlHeaders" {
#  name = "UseOriginCacheControlHeaders"
#}
resource "aws_cloudfront_cache_policy" "data" {
  name        = "${var.name_prefix}-data"
  comment     = "${var.name_prefix} CachingOptimized + min=0"
  default_ttl = 0
  max_ttl     = 31536000 # 1 yr
  min_ttl     = 0
  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "public" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
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
    cache_policy_id          = aws_cloudfront_cache_policy.data.id
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
