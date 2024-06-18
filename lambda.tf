locals {
  lambda_env_vars = merge({
    S3_BUCKET = aws_s3_bucket.bucket.bucket
    SECRET_ID = aws_secretsmanager_secret.secret.arn
  }, var.lambda_env_vars)
}

data "archive_file" "collector" {
  type        = "zip"
  source_dir  = "${path.module}/collector"
  output_path = "${path.module}/collector.zip"
}

resource "aws_lambda_function" "collector-action" {
  function_name = "${var.name_prefix}-collector-action"

  filename         = "${path.module}/collector.zip"
  source_code_hash = data.archive_file.collector.output_base64sha256
  handler          = "entrypoint.Publikes::LambdaHandler.action_handler"
  runtime          = "ruby3.2"
  architectures    = ["arm64"]

  role = aws_iam_role.Lambda.arn

  memory_size = 256
  timeout     = 60 * 15

  environment {
    variables = merge(local.lambda_env_vars, {
    })
  }
}

resource "aws_lambda_function" "collector-sqs" {
  function_name = "${var.name_prefix}-collector-sqs"

  filename         = "${path.module}/collector.zip"
  source_code_hash = data.archive_file.collector.output_base64sha256
  handler          = "entrypoint.Publikes::LambdaHandler.sqs_handler"
  runtime          = "ruby3.2"
  architectures    = ["arm64"]

  role = aws_iam_role.Lambda.arn

  memory_size = 256
  timeout     = 30

  environment {
    variables = merge(local.lambda_env_vars, {
      STATE_MACHINE_ARN_STORE_STATUS = aws_sfn_state_machine.store-status.arn,
      STATE_MACHINE_ARN_ROTATE_BATCH = aws_sfn_state_machine.rotate-batch.arn, #"arn:aws:states:${data.aws_region.current.id}:${data.aws_caller_identity.current.id}:stateMachine:${var.name_prefix}-rotate-batch"
    })
  }
}
resource "aws_lambda_event_source_mapping" "collector-sqs" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.collector-sqs.arn

  batch_size                         = 10
  maximum_batching_window_in_seconds = 60

  scaling_config {
    maximum_concurrency = 2
  }
}

resource "aws_lambda_function" "collector-http" {
  function_name = "${var.name_prefix}-collector-http"

  filename         = "${path.module}/collector.zip"
  source_code_hash = data.archive_file.collector.output_base64sha256
  handler          = "entrypoint.Publikes::LambdaHandler.http_handler"
  runtime          = "ruby3.2"
  architectures    = ["arm64"]

  role = aws_iam_role.Lambda.arn

  memory_size = 256
  timeout     = 15

  environment {
    variables = merge(local.lambda_env_vars, {
      SQS_QUEUE_URL = aws_sqs_queue.queue.url
    })
  }
}
resource "aws_lambda_function_url" "collector-http" {
  function_name      = aws_lambda_function.collector-http.function_name
  authorization_type = "NONE"
}
