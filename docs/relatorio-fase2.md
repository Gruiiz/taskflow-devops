# Relatório técnico - Fase 2

**Disciplina:** DevOps na Prática  
**Estudante:** Gabriel Ruiz Silva  
**Repositório:** https://github.com/Gruiiz/taskflow-devops

## 1. Visão geral

O projeto implementa um fluxo DevOps para a TaskFlow, uma API REST de tarefas em Python.
A Fase 1 estabeleceu versionamento, testes automatizados, integração contínua e
infraestrutura como código. A Fase 2 transforma os artefatos validados em imagens
versionadas e implantáveis, acrescentando entrega contínua, containers, orquestração,
monitoramento, logging, segurança e recuperação de falhas.

## 2. Resumo da Fase 1

Na configuração inicial foram entregues:

- código-fonte e testes no GitHub;
- pipeline executado em push e pull request;
- Ruff, cobertura mínima de 80% e build Docker;
- `terraform fmt`, `init -backend=false` e `validate`;
- infraestrutura alvo descrita com Terraform.

O principal resultado foi criar uma barreira automatizada antes da integração de código.

## 3. Pipeline de integração e entrega contínuas

O workflow `.github/workflows/ci.yml` reúne quatro estágios:

1. **qualidade, testes e segurança:** Ruff, Bandit e testes com cobertura;
2. **infraestrutura:** formatação e validação do Terraform;
3. **container:** build, scan com Trivy, execução e smoke test;
4. **entrega:** publicação da imagem no GHCR e promoção aprovada para AWS.

As imagens recebem o SHA completo do commit. Essa referência imutável relaciona código,
execução do pipeline e release, além de possibilitar rollback. O deploy é deliberadamente
autorizado para proteger o crédito do AWS Academy, mas a construção e a validação do
artefato são automáticas.

O workflow contém o job de implantação em ECR/ECS para contas AWS que autorizem runners
externos. No Learner Lab utilizado, uma política acadêmica com `explicit deny` impediu
`ecr:GetAuthorizationToken` no runner hospedado pelo GitHub. Por isso, a demonstração
adotou uma promoção controlada no terminal autenticado do próprio laboratório:

`GitHub Actions -> GHCR -> aprovação manual -> Amazon ECR -> ECS Fargate`.

Essa adaptação preserva os princípios de entrega contínua: um único artefato já testado,
tag imutável, aprovação explícita, implantação reproduzível e verificação pós-deploy.

## 4. Containerização e orquestração

O `Dockerfile` usa `python:3.12.14-alpine3.24` e usuário sem privilégios. O container possui
health check, metadados OCI e versão configurável por build argument. No Compose e no ECS
foram aplicados filesystem somente leitura, remoção de capabilities, processo init e
configurações por variáveis de ambiente.

O Terraform provisiona:

- Amazon ECR com criptografia, scan no push, tags imutáveis e retenção das 10 imagens mais
  recentes;
- ECS Fargate com uma task de 0,25 vCPU e 512 MiB;
- Application Load Balancer com health check em `/health`;
- VPC, duas sub-redes públicas e security groups que isolam o container do acesso direto;
- rolling update com circuit breaker e rollback automático.

## 5. Scripts de deploy

- `deploy-local.sh`: constrói e inicia a aplicação pelo Docker Compose;
- `bootstrap-aws.sh`: cria o ECR, publica a primeira imagem e provisiona a infraestrutura;
- `deploy-aws.sh`: publica uma versão imutável e atualiza a task definition;
- `smoke-test.sh`: valida saúde, versão e criação/listagem de tarefas;
- `rollback-aws.sh`: retorna à revisão anterior do ECS;
- `destroy-aws.sh`: destrói a infraestrutura mediante confirmação explícita.

No terminal web do laboratório, o cliente Docker estava instalado, mas o daemon não era
acessível. A promoção usou o Crane para copiar, sem rebuild, a imagem aprovada do GHCR para
o ECR. O Terraform então registrou uma nova revisão da task definition e atualizou o
serviço ECS.

## 6. Monitoramento e logging

Cada requisição produz um evento JSON com serviço, ambiente, versão, request ID, método,
rota, status HTTP e duração. O ECS encaminha os logs ao CloudWatch com retenção de sete
dias. Container Insights fornece métricas de CPU e memória. O Terraform também cria um
dashboard e alarmes para CPU, memória e erros 5xx no ALB.

Na validação prática foram observados:

- serviço ECS ativo, com uma task desejada e uma em execução;
- destino do Application Load Balancer íntegro;
- dashboard com CPU, memória, requisições e erros 5xx;
- logs estruturados recebidos no grupo `/ecs/taskflow-dev`;
- endpoints `/health` e `/version` acessíveis pelo endereço público do ALB.

## 7. Segurança e DevSecOps

Os controles implementados incluem:

- princípio de menor privilégio no container;
- limite de 16 KiB para o corpo de requisições;
- headers `nosniff`, CSP restritiva e política de referer;
- Bandit para análise estática e Trivy para vulnerabilidades da imagem;
- ECR privado, criptografado, com scan no push e tags imutáveis;
- credenciais fora do código e suporte a OIDC em contas compatíveis;
- ambiente GitHub `production` como barreira de entrega;
- Dependabot para GitHub Actions, Python, Docker e Terraform.

O primeiro scan da imagem baseada em Debian slim encontrou **4 vulnerabilidades críticas,
8 altas e 6 médias**. A imagem base foi substituída por Alpine 3.24, o pipeline completo
permaneceu aprovado e uma nova versão foi promovida. O scan final do ECR terminou com
status `COMPLETE` e `Findings: {}`, isto é, **zero achados**. Esse ciclo demonstra uma
correção DevSecOps mensurável, e não apenas a execução de uma ferramenta de scan.

## 8. Gerenciamento de configurações

Configurações não secretas são injetadas por variáveis de ambiente. O Terraform concentra
nomes, região, imagem e capacidade em variáveis tipadas e validadas. No AWS Academy, o ARN
da `LabRole` é fornecido sem tentar criar uma nova função IAM. Credenciais temporárias são
usadas apenas dentro da sessão autenticada do laboratório e nunca são versionadas.

## 9. Demonstração realizada

1. O código foi enviado ao GitHub.
2. O GitHub Actions aprovou qualidade, testes, segurança, Terraform, build e smoke test.
3. A imagem imutável foi publicada no GHCR com a tag do commit.
4. O Terraform criou o ECR e, depois, 20 recursos da aplicação e da observabilidade.
5. A imagem aprovada foi promovida do GHCR para o ECR sem rebuild.
6. O ECS estabilizou e o smoke test foi aprovado pela URL do ALB.
7. Foram conferidos serviço, imagem, dashboard, métricas, logs e endpoints na AWS.
8. Após o scan inicial, a base do container foi corrigida e o CI voltou a ficar verde.
9. A atualização gerou uma nova task definition e alterou o serviço ECS.
10. O segundo smoke test foi aprovado e o scan final apresentou zero achados.

## 10. Resultados obtidos

- CI executada com sucesso no GitHub Actions;
- imagem Docker versionada pelo SHA do commit e publicada no GHCR;
- infraestrutura criada por Terraform: `20 added, 0 changed, 0 destroyed`;
- atualização da versão: `1 added, 1 changed, 1 destroyed`;
- serviço ECS estável e destino do ALB íntegro;
- smoke test aprovado antes e depois da correção de segurança;
- logs e métricas disponíveis no CloudWatch;
- redução de 18 achados de vulnerabilidade para zero;
- limitação do AWS Academy documentada de forma transparente, com caminho alternativo
  reproduzível e sem reconstrução do artefato.

## 11. Melhorias futuras

- armazenar tarefas em Amazon RDS ou DynamoDB;
- adicionar HTTPS com ACM e Route 53;
- mover as tasks para sub-redes privadas com VPC endpoints;
- usar backend remoto do Terraform com locking;
- substituir credenciais temporárias por OIDC em uma conta que permita configurar IAM;
- implementar testes de carga e SLOs de disponibilidade e latência;
- assinar imagens e gerar SBOM e proveniência de build;
- criar ambientes separados de homologação e produção;
- adotar implantação blue/green ou canary.

## 12. Conclusão

A solução cobre o ciclo entre commit e operação: valida código e infraestrutura, constrói
e examina o container, publica um artefato imutável, promove a versão com aprovação,
implanta no ECS, executa testes pós-deploy e acompanha sua saúde no CloudWatch. A correção
da imagem e a queda de 18 achados para zero evidenciam a integração prática entre entrega
contínua, segurança e observabilidade. Os scripts e o Terraform tornam o processo
reproduzível e permitem encerrar a infraestrutura após a demonstração.
