data "aws_ssm_parameter" "db_password" {
  name            = "/assignment1/${var.environment}/db_password"
  with_decryption = true
}
