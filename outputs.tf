output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.public.domain_name
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.public.id
}

output "lambda_function_url" {
  value = aws_lambda_function_url.collector-http.function_url
}
