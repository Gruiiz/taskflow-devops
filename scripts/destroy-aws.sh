#!/usr/bin/env bash
set -Eeuo pipefail

expected_confirmation="${PROJECT_NAME:-taskflow}-${ENVIRONMENT:-dev}"
if [[ "${CONFIRM_DESTROY:-}" != "$expected_confirmation" ]]; then
  echo "Operação cancelada." >&2
  echo "Para destruir o ambiente, execute:" >&2
  echo "CONFIRM_DESTROY=${expected_confirmation} ./scripts/destroy-aws.sh" >&2
  exit 1
fi

command -v terraform >/dev/null || {
  echo "Terraform não encontrado." >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
terraform_args=(
  "-var=project_name=${PROJECT_NAME:-taskflow}"
  "-var=environment=${ENVIRONMENT:-dev}"
  "-var=aws_region=${AWS_REGION:-us-east-1}"
  "-var=container_image=destroy-placeholder"
)
if [[ -n "${ECS_EXECUTION_ROLE_ARN:-}" ]]; then
  terraform_args+=("-var=ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}")
fi

terraform -chdir="${repo_root}/infra" destroy "${terraform_args[@]}"
