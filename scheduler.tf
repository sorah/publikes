resource "aws_scheduler_schedule" "rotate-batch" {
  name = "${var.name_prefix}-rotate-batch"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 20
  }

  schedule_expression = "rate(6 hours)"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:sfn:startExecution"
    role_arn = aws_iam_role.Scheduler.arn

    input = jsonencode({
      StateMachineArn = aws_sfn_state_machine.rotate-batch.arn
      Input           = jsonencode({})
    })
  }
}
