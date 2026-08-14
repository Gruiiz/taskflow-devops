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

output "ecr_repository_url" {
  description = "Repositório privado para as imagens versionadas."
  value       = aws_ecr_repository.api.repository_url
}

output "ecs_service_name" {
  description = "Nome do serviço atualizado pelo pipeline de CD."
  value       = aws_ecs_service.api.name
}

output "ecs_task_family" {
  description = "Família da definição de tarefa do ECS."
  value       = aws_ecs_task_definition.api.family
}

output "cloudwatch_dashboard" {
  description = "Nome do painel operacional."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
