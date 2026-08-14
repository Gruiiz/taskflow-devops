# Infraestrutura Terraform

Este diretório descreve a execução da TaskFlow API no Amazon ECS Fargate. O código cria:

- Amazon ECR privado, criptografado, com scan no push e retenção de imagens;
- VPC, duas sub-redes públicas, gateway e regras de rede;
- Application Load Balancer e health check;
- cluster, task definition e serviço ECS Fargate;
- CloudWatch Logs, Container Insights, alarmes e dashboard;
- IAM task execution role, exceto quando uma role existente é fornecida.

## Validar sem criar recursos

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## AWS Academy

O Learner Lab normalmente fornece uma `LabRole`. Para reutilizá-la:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export ECS_EXECUTION_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
../scripts/bootstrap-aws.sh
```

Quando `ecs_execution_role_arn` é nulo, o Terraform cria e configura uma função própria.

## Primeiro provisionamento

Não execute um `terraform apply` completo antes de publicar uma imagem válida. O script de
bootstrap resolve a dependência em duas etapas:

1. cria o repositório ECR;
2. constrói e publica a imagem;
3. executa o apply completo usando a URI imutável da imagem.

```bash
../scripts/bootstrap-aws.sh
```

## Custos e limpeza

O Fargate, o Load Balancer, o CloudWatch e endereços IPv4 podem gerar cobranças. Destrua o
ambiente depois da demonstração:

```bash
CONFIRM_DESTROY=taskflow-dev ../scripts/destroy-aws.sh
```

O estado Terraform e `terraform.tfvars` não devem ser versionados.
