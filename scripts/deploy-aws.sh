#!/usr/bin/env bash
set -Eeuo pipefail

for required_command in aws docker jq curl python3; do
  command -v "$required_command" >/dev/null || {
    echo "Comando obrigatório não encontrado: ${required_command}" >&2
    exit 1
  }
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

aws_region="${AWS_REGION:-us-east-1}"
repository_name="${ECR_REPOSITORY:-taskflow}"
cluster_name="${ECS_CLUSTER:-taskflow-dev}"
service_name="${ECS_SERVICE:-taskflow-dev}"
task_family="${ECS_TASK_FAMILY:-taskflow-dev}"
container_name="${ECS_CONTAINER:-api}"
alb_name="${ALB_NAME:-taskflow-dev-alb}"
image_tag="${IMAGE_TAG:-$(git rev-parse --short=12 HEAD 2>/dev/null || date -u +%Y%m%d%H%M%S)}"

account_id="$(aws sts get-caller-identity --query Account --output text)"
registry="${account_id}.dkr.ecr.${aws_region}.amazonaws.com"
image_uri="${registry}/${repository_name}:${image_tag}"

aws ecr get-login-password --region "$aws_region" |
  docker login --username AWS --password-stdin "$registry"
docker build --build-arg "APP_VERSION=${image_tag}" --tag "$image_uri" .
docker push "$image_uri"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

aws ecs describe-task-definition \
  --region "$aws_region" \
  --task-definition "$task_family" \
  --query taskDefinition >"${work_dir}/current.json"

jq --arg image "$image_uri" --arg container "$container_name" --arg version "$image_tag" '
  .containerDefinitions |= map(
    if .name == $container then
      .image = $image |
      .environment = (((.environment // []) | map(select(.name != "APP_VERSION"))) +
        [{"name": "APP_VERSION", "value": $version}])
    else . end
  ) |
  del(
    .compatibilities,
    .registeredAt,
    .registeredBy,
    .requiresAttributes,
    .revision,
    .status,
    .taskDefinitionArn
  )
' "${work_dir}/current.json" >"${work_dir}/next.json"

task_definition_arn="$(aws ecs register-task-definition \
  --region "$aws_region" \
  --cli-input-json "file://${work_dir}/next.json" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)"

aws ecs update-service \
  --region "$aws_region" \
  --cluster "$cluster_name" \
  --service "$service_name" \
  --task-definition "$task_definition_arn" >/dev/null
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

./scripts/smoke-test.sh "$application_url"
echo "Versão ${image_tag} implantada em ${application_url}."
