variable "project_name" {
  description = "Nome curto usado nos recursos."
  type        = string
  default     = "taskflow"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "Use de 3 a 21 caracteres: letras minúsculas, números e hífen."
  }
}

variable "environment" {
  description = "Ambiente provisionado."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS."
  type        = string
  default     = "us-east-1"
}

variable "ecs_execution_role_arn" {
  description = "ARN de uma função existente, como LabRole; se nulo, o Terraform cria uma."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.ecs_execution_role_arn == null ||
      can(regex("^arn:aws:iam::[0-9]{12}:role/.+", var.ecs_execution_role_arn))
    )
    error_message = "Informe um ARN de função IAM válido ou mantenha null."
  }
}

variable "container_image" {
  description = "Imagem imutável da TaskFlow API armazenada no Amazon ECR."
  type        = string
}

variable "app_version" {
  description = "Versão imutável da aplicação exibida nos logs."
  type        = string
  default     = "bootstrap"
}

variable "log_level" {
  description = "Nível de log da aplicação."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "log_level deve ser DEBUG, INFO, WARNING ou ERROR."
  }
}

variable "container_port" {
  description = "Porta HTTP exposta pela aplicação."
  type        = number
  default     = 8000
}

variable "desired_count" {
  description = "Quantidade desejada de tarefas ECS."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 4
    error_message = "desired_count deve estar entre 1 e 4."
  }
}
