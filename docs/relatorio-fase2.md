# Relatório técnico - Fase 2

**Disciplina:** DevOps na Prática  
**Estudante:** Gabriel Ruiz Silva  
**Repositório:** https://github.com/Gruiiz/taskflow-devops

## 1. Visão geral

O projeto implementa um fluxo DevOps para a TaskFlow, uma API REST de tarefas em Python.
A Fase 1 estabeleceu versionamento, testes automatizados, integração contínua e
infraestrutura como código. A Fase 2 transforma os artefatos validados em imagens
versionadas e implantáveis, acrescentando entrega contínua, orquestração, observabilidade,
segurança e recuperação de falhas.

## 2. Resumo da Fase 1

Na configuração inicial foram entregues:

- código-fonte e testes no GitHub;
- pipeline executado em push e pull request;
- Ruff, cobertura mínima de 80% e build Docker;
- `terraform fmt`, `init -backend=false` e `validate`;
- infraestrutura alvo com VPC, duas sub-redes, ALB, ECS Fargate, IAM e CloudWatch Logs.

O principal resultado foi criar uma barreira automatizada antes da integração de código.

## 3. Pipeline de entrega contínua

O workflow `.github/workflows/ci.yml` reúne quatro estágios:

1. **qualidade, testes e segurança:** Ruff, Bandit e testes com cobertura;
2. **infraestrutura:** formatação e validação do Terraform;
3. **container:** build, scan com Trivy, execução e smoke test;
4. **entrega:** publicação no GHCR e, mediante aprovação, implantação no AWS ECS.

Imagens recebem o SHA do commit. Essa referência imutável relaciona código, execução do
pipeline e release, além de possibilitar rollback. O deploy AWS é manualmente autorizado
para proteger o crédito do AWS Academy, mas todo o preparo do artefato é automático.

## 4. Containerização e orquestração

O `Dockerfile` usa Python 3.12 slim e usuário sem privilégios. O container possui health
check, metadados OCI e versão configurável por build argument. No Compose e no ECS foram
aplicados filesystem somente leitura, remoção de capabilities, processo init e
configurações por variáveis de ambiente.

O Terraform provisiona:

- Amazon ECR com criptografia, scan no push, tags imutáveis e retenção das 10 imagens mais
  recentes;
- ECS Fargate com uma task de 0,25 vCPU e 512 MiB;
- Application Load Balancer com health check em `/health`;
- security groups que isolam o container do acesso direto;
- rolling update com circuit breaker e rollback automático.

## 5. Scripts de deploy

- `deploy-local.sh`: constrói e inicia a aplicação pelo Docker Compose;
- `bootstrap-aws.sh`: cria o ECR, publica a primeira imagem e provisiona a infraestrutura;
- `deploy-aws.sh`: publica uma versão imutável e atualiza a task definition;
- `smoke-test.sh`: valida saúde, versão e criação/listagem de tarefas;
- `rollback-aws.sh`: retorna à revisão anterior do ECS;
- `destroy-aws.sh`: destrói a infraestrutura mediante confirmação explícita.

## 6. Monitoramento e logging

Cada requisição produz um evento JSON com serviço, ambiente, versão, request ID, método,
rota, status HTTP e duração. O ECS encaminha os logs ao CloudWatch com retenção de sete
dias. Container Insights fornece métricas de CPU e memória. O Terraform também cria um
dashboard e alarmes para CPU, memória e erros 5xx no ALB.

## 7. Segurança

Os controles implementados incluem:

- princípio de menor privilégio no container;
- limite de 16 KiB para o corpo de requisições;
- headers `nosniff`, CSP restritiva e política de referer;
- Bandit para análise estática e Trivy para vulnerabilidades críticas da imagem;
- ECR privado e tags imutáveis;
- credenciais fora do código e suporte a OIDC;
- ambiente GitHub `production` como barreira de entrega;
- Dependabot para GitHub Actions, Python e Terraform.

## 8. Gerenciamento de configurações

Configurações não secretas são injetadas por variáveis de ambiente. O Terraform concentra
nomes, região, imagem e capacidade em variáveis tipadas e validadas. No AWS Academy, o ARN
da `LabRole` pode ser fornecido sem tentar criar uma nova função IAM. Credenciais
temporárias permanecem somente no terminal ou nos secrets protegidos do GitHub.

## 9. Demonstração do fluxo

1. Alterar o código e abrir push ou pull request.
2. Observar as verificações de qualidade, testes, segurança e Terraform.
3. Verificar o build, Trivy e smoke test do container.
4. Confirmar a imagem publicada no GHCR com a tag do commit.
5. Iniciar o Learner Lab e atualizar os secrets temporários.
6. Executar o workflow manual com `deploy_aws=true`.
7. Acessar `/health` e `/version` na URL do ALB.
8. Consultar logs, métricas, alarmes e dashboard no CloudWatch.
9. Demonstrar rollback ou descrever o circuit breaker.
10. Executar `destroy-aws.sh` para encerrar os recursos.

## 10. Resultados e melhorias futuras

O fluxo reduz falhas manuais ao aplicar as mesmas verificações em cada mudança e produzir
releases rastreáveis. Health checks, smoke test e rollback diminuem o risco de disponibilizar
uma versão inválida. A observabilidade permite relacionar uma requisição à versão implantada.

Melhorias futuras sugeridas:

- armazenar tarefas em Amazon RDS ou DynamoDB;
- adicionar HTTPS com ACM e Route 53;
- mover as tasks para sub-redes privadas com VPC endpoints;
- usar backend remoto do Terraform com locking;
- implementar testes de carga e SLOs de disponibilidade/latência;
- assinar imagens e gerar SBOM e proveniência de build;
- criar ambientes separados de homologação e produção;
- adotar implantação blue/green ou canary.

## 11. Conclusão

A solução cobre o ciclo entre commit e operação: valida código e infraestrutura, constrói
e examina o container, publica um artefato imutável, implanta no ECS com aprovação, testa
a versão em execução e acompanha sua saúde no CloudWatch. Os scripts e o Terraform tornam
o processo reproduzível e permitem encerrar a infraestrutura após a demonstração.
