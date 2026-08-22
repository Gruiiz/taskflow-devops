# TaskFlow API - DevOps na Prática

[![CI/CD](https://github.com/Gruiiz/taskflow-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Gruiiz/taskflow-devops/actions/workflows/ci.yml)

Projeto acadêmico de Gabriel Ruiz Silva para demonstrar um fluxo DevOps completo. A
TaskFlow é uma API REST de tarefas em Python 3.12, acompanhada por testes automatizados,
container Docker, pipeline de CI/CD no GitHub Actions e infraestrutura AWS declarada com
Terraform.

## O que está implementado

- qualidade, análise estática de segurança, testes e cobertura mínima de 80%;
- validação automática do Terraform;
- build, smoke test e scan de vulnerabilidades da imagem Docker;
- publicação automática de imagens versionadas no GitHub Container Registry;
- promoção aprovada para Amazon ECR e Amazon ECS Fargate;
- health checks, rollback automático e logs estruturados no CloudWatch;
- alarmes de CPU, memória e erros HTTP 5xx, além de dashboard operacional;
- scripts de deploy local, bootstrap AWS, atualização, rollback e destruição.

## Fluxo de CI/CD

```mermaid
flowchart TD
    A[Push ou pull request] --> B[Qualidade, Bandit e testes]
    A --> C[Terraform fmt e validate]
    B --> D[Build, Trivy e smoke test]
    C --> D
    D --> E[Imagem imutável no GHCR]
    E --> F{Promoção aprovada}
    F --> G[Runner autorizado ou terminal Academy]
    G --> H[Amazon ECR]
    H --> I[ECS Fargate e ALB]
    I --> J[Smoke test e CloudWatch]
    I -->|falha| K[Rollback automático]
```

O push em `main` publica uma imagem rastreável pelo SHA completo do commit. Em contas AWS
que autorizam runners externos, o job manual do GitHub Actions promove a versão ao ECR e
ao ECS. No AWS Academy usado na demonstração, uma política acadêmica bloqueou credenciais
fora do laboratório; por isso, o mesmo artefato aprovado foi promovido pelo terminal
autenticado do Learner Lab, sem rebuild.

## Estrutura do repositório

```text
.
├── .github/workflows/ci.yml  # integração e entrega contínuas
├── app/                      # API e logs estruturados
├── tests/                    # testes unitários e de integração
├── infra/                    # ECR, ECS, ALB, CloudWatch e rede
├── scripts/                  # deploy, smoke test, rollback e limpeza
├── docs/                     # arquitetura e relatório das fases
├── Dockerfile
└── compose.yaml
```

## Executar testes e verificações

Requisito: Python 3.12 ou superior.

```bash
python -m pip install --requirement requirements-dev.txt
make quality
make security
make test
```

## Executar com Docker

```bash
./scripts/deploy-local.sh
curl http://localhost:8000/health
curl http://localhost:8000/version
docker compose down
```

A imagem usa `python:3.12.14-alpine3.24` e executa sem privilégios, com filesystem somente
leitura, capabilities removidas, health check e limite de rotação dos logs locais.

## Implantar no AWS Academy

O guia completo está em [docs/aws-academy.md](docs/aws-academy.md). Ele documenta dois
caminhos:

- `bootstrap-aws.sh`, quando o daemon Docker está disponível;
- promoção da imagem aprovada do GHCR para o ECR com Crane, quando o terminal web não
  permite usar o daemon Docker ou credenciais em runners externos.

Em ambos os casos, o Terraform cria VPC, ECR, ECS Fargate, ALB, CloudWatch e controles de
segurança. Nenhuma credencial é gravada no repositório.

> O ECS Fargate, o Application Load Balancer, o CloudWatch e endereços IPv4 podem consumir
> os créditos da conta. Ao terminar a demonstração, destrua o ambiente.

```bash
CONFIRM_DESTROY=taskflow-dev ./scripts/destroy-aws.sh
```

## Resultado prático de segurança

O scan inicial encontrou 4 vulnerabilidades críticas, 8 altas e 6 médias. Após a troca da
base Debian slim por Alpine 3.24, o pipeline permaneceu verde, a nova imagem foi implantada
e o scan final do ECR apresentou zero achados.

## Endpoints

- `GET /health`: saúde da aplicação;
- `GET /version`: versão implantada e ambiente;
- `GET /tasks`: lista tarefas;
- `POST /tasks`: cria uma tarefa;
- `GET /tasks/{id}`: consulta uma tarefa;
- `DELETE /tasks/{id}`: remove uma tarefa.

## Documentação

- [Arquitetura e fluxo completo](docs/architecture.md)
- [Configuração do AWS Academy](docs/aws-academy.md)
- [Relatório técnico da Fase 2](docs/relatorio-fase2.md)
- [Infraestrutura Terraform](infra/README.md)

## Referências oficiais

- [GitHub Actions: implantação no Amazon ECS](https://docs.github.com/actions/deployment/deploying-to-your-cloud-provider/deploying-to-amazon-elastic-container-service)
- [GitHub Actions: OpenID Connect na AWS](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Amazon ECS com Application Load Balancer](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html)
- [Circuit breaker e rollback do Amazon ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html)
