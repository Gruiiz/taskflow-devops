#!/usr/bin/env bash
set -Eeuo pipefail

for required_command in aws jq curl python3; do
  command -v "$required_command" >/dev/null || {
    echo "Comando obrigatório não encontrado: ${required_command}" >&2
    exit 1
  }
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aws_region="${AWS_REGION:-us-east-1}"
cluster_name="${ECS_CLUSTER:-taskflow-dev}"
service_name="${ECS_SERVICE:-taskflow-dev}"
task_family="${ECS_TASK_FAMILY:-taskflow-dev}"
alb_name="${ALB_NAME:-taskflow-dev-alb}"

current_arn="$(aws ecs describe-services \
  --region "$aws_region" \
  --cluster "$cluster_name" \
  --services "$service_name" \
  --query 'services[0].taskDefinition' \
  --output text)"

previous_arn="$(aws ecs list-task-definitions \
  --region "$aws_region" \
  --family-prefix "$task_family" \
  --status ACTIVE \
  --sort DESC |
  jq -r --arg current "$current_arn" '.taskDefinitionArns[] | select(. != $current)' |
  head -n 1)"

if [[ -z "$previous_arn" ]]; then
  echo "Nenhuma revisão anterior foi encontrada para rollback." >&2
  exit 1
fi

aws ecs update-service \
  --region "$aws_region" \
  --cluster "$cluster_name" \
  --service "$service_name" \
  --task-definition "$previous_arn" >/dev/null
aws ecs wait services-stable \
  --region "$aws_region" \
  --cluster "$cluster_name" \
  --services "$service_name"

application_url="${APPLICATION_URL:-}"
if [[ -z "$application_url" ]]; then
  alb_dns="$(aws elbv2 describe-load-balancers \
    --region "$aws_region" \
    --names "$alb_name" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)"
  application_url="http://${alb_dns}"
fi

"${repo_root}/scripts/smoke-test.sh" "$application_url"
echo "Rollback concluído para ${previous_arn}."
