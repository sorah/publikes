resource "aws_secretsmanager_secret" "secret" {
  name = "${var.name_prefix}/secret"
}
