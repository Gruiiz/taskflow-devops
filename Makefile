.PHONY: run test quality docker-build terraform-check

run:
	python -m app.main

test:
	python -m unittest discover -s tests -p "test_*.py" -v

quality:
	ruff check app tests

docker-build:
	docker build -t taskflow-api:local .

terraform-check:
	terraform -chdir=infra fmt -check -recursive
	terraform -chdir=infra init -backend=false
	terraform -chdir=infra validate
