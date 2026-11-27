output "vpc_id" {
  description = "Id of the VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet ids, keyed like var.public_subnets."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "web_instance_id" {
  description = "Instance id of the web server (used by the CloudWatch alarm)."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to curl once the instance has booted."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "db_password" {
  description = "Application secret read from SSM Parameter Store."
  value       = data.aws_ssm_parameter.db_password.value
  sensitive   = true
}

output "cpu_alarm_name" {
  description = "Name of the CloudWatch CPU alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}
