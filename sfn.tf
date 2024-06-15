locals {
  sfn_tfstate = {
    s3_bucket         = aws_s3_bucket.bucket.bucket
    lambda_arn_action = aws_lambda_function.collector-action.arn
  }
}

data "external" "sfn-store-status" {
  program = ["jrsonnet", "--ext-str", "TFSTATE=${jsonencode(local.sfn_tfstate)}", "${path.module}/sfn-store-status.jsonnet"]
}
resource "aws_sfn_state_machine" "store-status" {
  name       = "${var.name_prefix}-store-status"
  role_arn   = aws_iam_role.States.arn
  definition = data.external.sfn-store-status.result.definition
}

data "external" "sfn-rotate-batch" {
  program = ["jrsonnet", "--ext-str", "TFSTATE=${jsonencode(local.sfn_tfstate)}", "${path.module}/sfn-rotate-batch.jsonnet"]
}
moved {
  from = aws_sfn_state_machine.store-rotate-batch
  to   = aws_sfn_state_machine.rotate-batch
}
resource "aws_sfn_state_machine" "rotate-batch" {
  name       = "${var.name_prefix}-rotate-batch"
  role_arn   = aws_iam_role.States.arn
  definition = data.external.sfn-rotate-batch.result.definition
}
