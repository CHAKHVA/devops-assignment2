.DEFAULT_GOAL := help
SHELL := /bin/bash

.PHONY: help setup up down restart logs ps test lint scan verify deploy rollback clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## One-command bootstrap: create .env (if missing) and start the full stack
	@./scripts/setup.sh

up: ## Build and start the full stack in the background
	@docker compose up -d --build

down: ## Stop and remove all containers
	@docker compose down

restart: ## Restart the stack
	@docker compose down && docker compose up -d --build

logs: ## Follow logs from all services
	@docker compose logs -f

ps: ## Show container status
	@docker compose ps

test: ## Run the application unit tests
	@cd app && python -m pytest -q

lint: ## Lint the application code
	@cd app && ruff check .

scan: ## Run the local security scan suite (deps, image, secrets, config)
	@./scripts/scan.sh

verify: ## Verify the running stack is healthy (post-deploy checks)
	@./scripts/verify.sh

deploy: ## Build a versioned image and deploy locally, then verify
	@./scripts/deploy.sh

rollback: ## Roll back to the previous image tag
	@./scripts/rollback.sh

clean: ## Stop the stack and remove volumes (DESTROYS data)
	@docker compose down -v
