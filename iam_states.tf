resource "aws_iam_role" "States" {
  name                 = "${var.iam_role_prefix}States"
  description          = "publikes ${var.name_prefix} States"
  assume_role_policy   = data.aws_iam_policy_document.States-trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "States-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "states.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "States" {
  role   = aws_iam_role.States.name
  policy = data.aws_iam_policy_document.States.json
}

data "aws_iam_policy_document" "States" {
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
      "${aws_s3_bucket.bucket.arn}/data/private/locks/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
    ]
    resources = [
      "${aws_s3_bucket.bucket.arn}/data/private/locks/*",
    ]
  }
}

resource "aws_iam_role_policy" "States2" {
  role   = aws_iam_role.States.name
  policy = data.aws_iam_policy_document.States2.json
}
data "aws_iam_policy_document" "States2" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.collector-action.arn,
    ]
  }
}
