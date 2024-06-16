output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.public.domain_name
}
