resource "aws_iam_role" "Scheduler" {
  name                 = "${var.iam_role_prefix}Scheduler"
  description          = "publikes ${var.name_prefix} Scheduler"
  assume_role_policy   = data.aws_iam_policy_document.Scheduler-trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "Scheduler-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "scheduler.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "Scheduler" {
  role   = aws_iam_role.Scheduler.name
  policy = data.aws_iam_policy_document.Scheduler.json
}

data "aws_iam_policy_document" "Scheduler" {
  statement {
    effect = "Allow"
    actions = [
      "states:StartExecution",
    ]
    resources = [
      aws_sfn_state_machine.rotate-batch.arn,
    ]
  }
}
