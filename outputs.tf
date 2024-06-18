output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.public.domain_name
}

output "lambda_function_url" {
  value = aws_lambda_function_url.collector-http.function_url
}
