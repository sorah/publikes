resource "aws_iam_role" "Lambda" {
  name                 = "${var.iam_role_prefix}Lambda"
  description          = "publikes ${var.name_prefix} Lambda"
  assume_role_policy   = data.aws_iam_policy_document.Lambda-trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "Lambda-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "Lambda" {
  role   = aws_iam_role.Lambda.name
  policy = data.aws_iam_policy_document.Lambda.json
}

data "aws_iam_policy_document" "Lambda" {
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.secret.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.bucket.arn,
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.bucket.arn}/data/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.bucket.arn}/data/public/pages/head/*",
      "${aws_s3_bucket.bucket.arn}/data/private/locks/*",
    ]
  }
}

resource "aws_iam_role_policy" "Lambda2" {
  role   = aws_iam_role.Lambda.name
  policy = data.aws_iam_policy_document.Lambda2.json
}
data "aws_iam_policy_document" "Lambda2" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",

      # Used by AWS control plane
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [
      aws_sqs_queue.queue.arn,
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "states:StartExecution",
    ]
    resources = [
      aws_sfn_state_machine.store-status.arn,
      aws_sfn_state_machine.rotate-batch.arn,
    ]
  }
}

resource "aws_iam_role_policy_attachment" "function-AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.Lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
