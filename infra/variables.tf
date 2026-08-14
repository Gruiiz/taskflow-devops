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

variable "container_image" {
  description = "Imagem pública da TaskFlow API, por exemplo ghcr.io/usuario/taskflow-api:latest."
  type        = string
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
