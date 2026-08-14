# Infraestrutura Terraform

Este diretório descreve uma execução da TaskFlow API no AWS ECS Fargate, exposta por um
Application Load Balancer. O código cria VPC, duas sub-redes públicas, regras de rede,
cluster e serviço ECS, definição de tarefa, logs no CloudWatch e balanceador.

## Validação sem criar recursos

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## Provisionamento manual

> Atenção: `terraform apply` cria recursos cobrados pela AWS. Use uma conta acadêmica ou
> sandbox e execute `terraform destroy` ao concluir a demonstração.

```bash
cp terraform.tfvars.example terraform.tfvars
# Edite container_image com a imagem publicada.
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

O pipeline executa apenas `fmt`, `init -backend=false` e `validate`. Credenciais AWS não
são armazenadas no repositório e o provisionamento não é disparado automaticamente.
