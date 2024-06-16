variable "iam_role_prefix" {
  type = string
}
variable "name_prefix" {
  type = string
}
variable "s3_bucket_name" {
  type = string
}

variable "app_domain" {
  type = string
}
variable "certificate_arn" {
  type = string
}
variable "cloudfront_log_bucket" {
  type = string
}
variable "cloudfront_log_prefix" {
  type = string
}

variable "lambda_env_vars" {
  type    = map(string)
  default = {}
}
