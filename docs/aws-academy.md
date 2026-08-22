# Implantação no AWS Academy Learner Lab

Este guia usa credenciais temporárias. Nunca envie chaves pelo chat, nunca salve o arquivo
de credenciais no repositório e nunca faça commit de `terraform.tfstate`.

## 1. Preparar o laboratório

1. Inicie o Learner Lab e aguarde o indicador ficar verde.
2. Use o terminal web autenticado fornecido pelo laboratório.
3. Confirme a sessão e a região:

```bash
aws sts get-caller-identity
aws configure get region
```

4. Na raiz do repositório, prepare as variáveis:

```bash
export PATH="$HOME/.local/bin:$PATH"
export AWS_REGION="us-east-1"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export ECS_EXECUTION_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
```

O ARN não é uma senha. As chaves `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
`AWS_SESSION_TOKEN` são secretas, temporárias e não devem ser versionadas.

## 2. Entender a restrição do Learner Lab

Algumas turmas do AWS Academy aplicam uma política, como `voc-cancel-cred`, que nega o uso
das credenciais temporárias fora do ambiente do laboratório. Nesse caso, um runner
hospedado pelo GitHub recebe `explicit deny` ao solicitar `ecr:GetAuthorizationToken`,
mesmo quando os três valores foram cadastrados corretamente.

Isso é uma restrição da plataforma acadêmica, não uma falha da aplicação. Não tente
contornar a política. Use a promoção controlada descrita abaixo e remova dos GitHub Secrets
qualquer credencial temporária que tenha sido testada.

Em uma conta AWS sem essa restrição, o job `Entrega aprovada no AWS ECS` pode usar OIDC ou
credenciais autorizadas e executar a implantação diretamente.

## 3. Validar o Terraform

```bash
terraform -chdir=infra init
terraform -chdir=infra validate
```

Se o terminal não possuir Terraform, instale-o no diretório local do usuário e nunca use
`sudo` no Learner Lab.

## 4. Caminho padrão quando o Docker funciona

Se `docker info` funcionar, execute:

```bash
./scripts/bootstrap-aws.sh
```

O script cria o ECR, constrói e publica a primeira imagem, provisiona VPC, ALB, ECS e
CloudWatch e executa o smoke test.

## 5. Caminho usado no terminal sem daemon Docker

O terminal web pode ter apenas o cliente Docker e negar acesso ao daemon. Nesse cenário,
promova a imagem já construída e testada pelo GitHub Actions, sem rebuild.

### 5.1 Criar somente o repositório ECR

O uso de `-target` ocorre apenas neste bootstrap excepcional. Depois dele, sempre gere um
plano completo.

```bash
terraform -chdir=infra apply \
  -target=aws_ecr_repository.api \
  -target=aws_ecr_lifecycle_policy.api \
  -var="ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}"
```

### 5.2 Promover do GHCR para o ECR

Use o SHA completo de um commit cujo pipeline esteja verde:

```bash
IMAGE_TAG="$(git rev-parse HEAD)"
ECR_REPOSITORY="$(terraform -chdir=infra output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_REPOSITORY%/*}"
IMAGE_URI="${ECR_REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password --region "$AWS_REGION" \
  | crane auth login --username AWS --password-stdin "$ECR_REGISTRY"

crane copy \
  "ghcr.io/gruiiz/taskflow-api:${IMAGE_TAG}" \
  "$IMAGE_URI"

crane digest "$IMAGE_URI"
```

O Crane apenas transfere o mesmo conteúdo entre registries. Não altera nem reconstrói a
imagem que passou pelo CI.

### 5.3 Provisionar a infraestrutura completa

```bash
terraform -chdir=infra plan \
  -var="ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}" \
  -var="container_image=${IMAGE_URI}" \
  -out=/tmp/taskflow.tfplan

terraform -chdir=infra apply /tmp/taskflow.tfplan
```

### 5.4 Aguardar e testar

```bash
APPLICATION_URL="$(terraform -chdir=infra output -raw application_url)"

aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster taskflow-dev \
  --services taskflow-dev

./scripts/smoke-test.sh "$APPLICATION_URL"
curl -s "$APPLICATION_URL/version"
```

## 6. Promover uma nova versão

Depois que um novo commit passar no GitHub Actions:

```bash
git pull
IMAGE_TAG="$(git rev-parse HEAD)"
ECR_REPOSITORY="$(terraform -chdir=infra output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_REPOSITORY%/*}"
IMAGE_URI="${ECR_REPOSITORY}:${IMAGE_TAG}"

aws ecr get-login-password --region "$AWS_REGION" \
  | crane auth login --username AWS --password-stdin "$ECR_REGISTRY"
crane copy "ghcr.io/gruiiz/taskflow-api:${IMAGE_TAG}" "$IMAGE_URI"

terraform -chdir=infra plan \
  -var="ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}" \
  -var="container_image=${IMAGE_URI}" \
  -out=/tmp/taskflow-update.tfplan
terraform -chdir=infra apply /tmp/taskflow-update.tfplan

APPLICATION_URL="$(terraform -chdir=infra output -raw application_url)"
aws ecs wait services-stable \
  --region "$AWS_REGION" \
  --cluster taskflow-dev \
  --services taskflow-dev
./scripts/smoke-test.sh "$APPLICATION_URL"
```

## 7. Verificar segurança e observabilidade

Scan da imagem promovida:

```bash
aws ecr describe-image-scan-findings \
  --repository-name taskflow \
  --image-id "imageTag=${IMAGE_TAG}" \
  --query '{Status:imageScanStatus.status,Findings:imageScanFindings.findingSeverityCounts}' \
  --output json
```

Logs recentes:

```bash
aws logs tail /ecs/taskflow-dev --since 10m --follow
```

No console, registre como evidência o serviço ECS estável, a imagem no ECR, o scan, o
dashboard `taskflow-dev-operations` e os eventos JSON no CloudWatch Logs.

## 8. Encerrar custos e credenciais

Depois de capturar as evidências, destrua o ambiente:

```bash
CONFIRM_DESTROY=taskflow-dev ./scripts/destroy-aws.sh
```

Digite `yes` se o Terraform pedir confirmação. Depois confirme que
`terraform -chdir=infra state list` não retorna recursos e finalize a sessão com `End Lab`.

Se credenciais temporárias foram adicionadas ao ambiente `production` do GitHub, exclua os
três secrets. Nunca clique em `Reset` apenas para encerrar uma demonstração; use o script de
destruição e verifique a remoção dos recursos.
