# Implantação no AWS Academy Learner Lab

Este guia usa credenciais temporárias. Nunca envie chaves pelo chat, nunca salve o arquivo
de credenciais no repositório e nunca faça commit de `terraform.tfstate`.

## 1. Preparar o laboratório

1. Inicie o Learner Lab e aguarde o indicador ficar verde.
2. Abra `AWS Details` e copie o bloco de credenciais para `~/.aws/credentials`, conforme a
   orientação da própria plataforma.
3. Confirme a sessão:

```bash
aws sts get-caller-identity
```

4. Obtenha o Account ID e construa o ARN da função acadêmica:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export ECS_EXECUTION_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/LabRole"
export AWS_REGION="us-east-1"
```

O ARN não é uma senha. As chaves `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e
`AWS_SESSION_TOKEN` são secretas e temporárias.

## 2. Fazer o primeiro provisionamento

Na raiz do repositório, execute:

```bash
./scripts/bootstrap-aws.sh
```

O script pede confirmação do Terraform em dois momentos:

1. cria o ECR;
2. constrói e publica a primeira imagem;
3. cria VPC, sub-redes, ALB, ECS, logs, métricas e alarmes;
4. executa o smoke test na URL pública.

Para uma demonstração assistida e sem prompts, use `AUTO_APPROVE=1`. Leia o plano antes de
adotar essa opção.

## 3. Configurar o ambiente production no GitHub

Em `Settings > Environments`, crie o ambiente `production`. Se sua modalidade do GitHub
permitir, habilite aprovação obrigatória.

Enquanto o Learner Lab estiver ativo, cadastre estes **Environment secrets**:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`.

As credenciais expiram quando a sessão termina. Atualize os três secrets antes de cada
demonstração. Não use credenciais da conta root.

As variáveis abaixo são opcionais porque o workflow possui valores acadêmicos padrão:

| Variável | Valor padrão |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `ECR_REPOSITORY` | `taskflow` |
| `ECS_CLUSTER` | `taskflow-dev` |
| `ECS_SERVICE` | `taskflow-dev` |
| `ECS_TASK_FAMILY` | `taskflow-dev` |
| `ALB_NAME` | `taskflow-dev-alb` |
| `APPLICATION_URL` | descoberta automaticamente pelo ALB |

Se o laboratório permitir uma relação de confiança OIDC, cadastre `AWS_ROLE_ARN` como
Environment variable. Quando ela existe, o workflow ignora as credenciais temporárias e
solicita um token de curta duração diretamente à AWS.

## 4. Demonstrar a entrega contínua

1. Abra a aba `Actions` do repositório.
2. Selecione `CI/CD - TaskFlow`.
3. Clique em `Run workflow`.
4. Marque `Implantar a versão validada no AWS ECS`.
5. Aprove o ambiente `production`, quando solicitado.

O job autentica na AWS, publica uma imagem com a tag do commit no ECR, registra uma nova
revisão da task definition, atualiza o ECS, aguarda estabilidade e executa o smoke test.

## 5. Operações manuais

Nova entrega usando as credenciais do terminal:

```bash
./scripts/deploy-aws.sh
```

Rollback para a revisão anterior:

```bash
./scripts/rollback-aws.sh
```

Logs recentes:

```bash
aws logs tail /ecs/taskflow-dev --since 10m --follow
```

## 6. Encerrar custos

Depois de capturar as evidências da demonstração, destrua o ambiente:

```bash
CONFIRM_DESTROY=taskflow-dev ./scripts/destroy-aws.sh
```

Confirme também no console se não restaram tarefas ECS, Load Balancer ou imagens do ECR.
