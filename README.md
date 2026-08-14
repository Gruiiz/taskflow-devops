# TaskFlow API — DevOps na Prática (Fase 1)

[![CI](https://github.com/Gruiiz/taskflow-devops/actions/workflows/ci.yml/badge.svg)](https://github.com/Gruiiz/taskflow-devops/actions/workflows/ci.yml)

Projeto acadêmico que demonstra configuração e automação inicial de um fluxo DevOps. A
aplicação é uma API REST de tarefas em Python 3.12, com testes automatizados, imagem Docker,
pipeline de integração contínua no GitHub Actions e infraestrutura AWS declarada em
Terraform.

## Objetivos da Fase 1

- versionar aplicação, testes e infraestrutura no mesmo repositório;
- executar testes e controles de qualidade a cada push e pull request;
- validar a imagem Docker antes da integração;
- validar automaticamente a formatação e a sintaxe do Terraform;
- manter o provisionamento real como ação manual e consciente de custos.

## Estrutura

```text
.
├── .github/workflows/ci.yml   # pipeline de CI
├── app/                       # código da API
├── tests/                     # testes unitários e de integração
├── infra/                     # infraestrutura AWS com Terraform
├── docs/architecture.md       # decisões e diagramas
├── Dockerfile
└── compose.yaml
```

## Executar localmente

Requisito: Python 3.12 ou superior.

```bash
python -m app.main
```

Em outro terminal:

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Validar pipeline"}'
curl http://localhost:8000/tasks
```

## Testes automatizados

Os testes usam `unittest` e não exigem dependências para a execução básica:

```bash
python -m unittest discover -s tests -p "test_*.py" -v
```

O CI também instala as ferramentas descritas em `requirements-dev.txt`, executa Ruff e
exige cobertura mínima de 80%.

## Docker

```bash
docker compose up --build
```

A imagem executa com usuário sem privilégios e inclui health check em `/health`.

## Pipeline de integração contínua

O workflow `.github/workflows/ci.yml` é disparado em pushes e pull requests para `main` e
possui três jobs:

1. qualidade, testes e cobertura;
2. formatação e validação do Terraform;
3. build da imagem Docker, liberado após os testes.

Nenhuma credencial de nuvem é necessária para o CI desta fase.

## Infraestrutura como código

O diretório `infra/` provisiona VPC, duas sub-redes, Application Load Balancer, ECS Fargate,
IAM e CloudWatch Logs. Consulte [infra/README.md](infra/README.md) antes de executar `apply`.

## Critérios de aceite

- `GET /health` responde HTTP 200;
- os testes automatizados passam;
- a cobertura permanece em pelo menos 80%;
- a imagem Docker é construída com sucesso;
- `terraform fmt -check` e `terraform validate` passam;
- nenhum segredo ou arquivo de estado Terraform é versionado.

## Referências oficiais

- [GitHub Actions](https://docs.github.com/actions)
- [Automação com Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Amazon ECS com Application Load Balancer](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/alb.html)
