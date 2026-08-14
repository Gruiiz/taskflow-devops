.PHONY: run test quality security docker-build deploy-local smoke terraform-check

run:
	python -m app.main

test:
	python -m unittest discover -s tests -p "test_*.py" -v

quality:
	ruff check app tests

security:
	bandit -q -r app

docker-build:
	docker build --build-arg APP_VERSION=local -t taskflow-api:local .

deploy-local:
	./scripts/deploy-local.sh

smoke:
	./scripts/smoke-test.sh http://localhost:8000

terraform-check:
	terraform -chdir=infra fmt -check -recursive
	terraform -chdir=infra init -backend=false
	terraform -chdir=infra validate
