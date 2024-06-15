resource "aws_sqs_queue" "queue" {
  name = var.name_prefix

  visibility_timeout_seconds = 60 + (30 * 6)

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 10
  })
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name_prefix}-dlq"

  visibility_timeout_seconds = 60
}
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.queue.arn]
  })
}

