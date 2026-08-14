#!/usr/bin/env bash
set -Eeuo pipefail

for required_command in aws docker terraform curl python3; do
  command -v "$required_command" >/dev/null || {
    echo "Comando obrigatório não encontrado: ${required_command}" >&2
    exit 1
  }
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

aws_region="${AWS_REGION:-us-east-1}"
image_tag="${IMAGE_TAG:-$(git rev-parse --short=12 HEAD 2>/dev/null || date -u +%Y%m%d%H%M%S)}"
terraform_args=(
  "-var=aws_region=${aws_region}"
  "-var=container_image=bootstrap"
)

if [[ -n "${ECS_EXECUTION_ROLE_ARN:-}" ]]; then
  terraform_args+=("-var=ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}")
fi

approval_args=()
if [[ "${AUTO_APPROVE:-0}" == "1" ]]; then
  approval_args=(-auto-approve)
fi

aws sts get-caller-identity >/dev/null
terraform -chdir=infra init

# O ECR precisa existir antes que a primeira imagem possa ser publicada.
terraform -chdir=infra apply \
  -target=aws_ecr_repository.api \
  -target=aws_ecr_lifecycle_policy.api \
  "${terraform_args[@]}" \
  "${approval_args[@]}"

ecr_repository="$(terraform -chdir=infra output -raw ecr_repository_url)"
aws ecr get-login-password --region "$aws_region" |
  docker login --username AWS --password-stdin "${ecr_repository%%/*}"

image_uri="${ecr_repository}:${image_tag}"
docker build --build-arg "APP_VERSION=${image_tag}" --tag "$image_uri" .
docker push "$image_uri"

full_apply_args=(
  "-var=aws_region=${aws_region}"
  "-var=container_image=${image_uri}"
  "-var=app_version=${image_tag}"
)
if [[ -n "${ECS_EXECUTION_ROLE_ARN:-}" ]]; then
  full_apply_args+=("-var=ecs_execution_role_arn=${ECS_EXECUTION_ROLE_ARN}")
fi

terraform -chdir=infra apply "${full_apply_args[@]}" "${approval_args[@]}"
application_url="$(terraform -chdir=infra output -raw application_url)"
./scripts/smoke-test.sh "$application_url"

echo "Infraestrutura e primeira versão implantadas em ${application_url}."
echo "Ao terminar a demonstração, execute CONFIRM_DESTROY=taskflow-dev ./scripts/destroy-aws.sh"
