output "application_url" {
  description = "URL pública da API."
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS."
  value       = aws_ecs_cluster.main.name
}

output "cloudwatch_log_group" {
  description = "Grupo de logs da aplicação."
  value       = aws_cloudwatch_log_group.api.name
}
