# Runs NotificationService on its own: Kafka from docker-compose.yml plus the app, no other service.
# GMAIL_PASSWORD, SERVER_PORT, EUREKA_CLIENT_ENABLED and the other settings come from the gitignored .env
# (see .env.example; `make env` creates it). Without it the defaults in application.properties apply (Kafka on
# 9092, Eureka on 8761). Spring resolves them at runtime, so the jar contains only ${...} placeholders, never the
# values. The root Makefile of the monorepo runs the whole stack instead (`make notification`).
#
#   make up        start Kafka, then run the app in the foreground on :8006
#   make down      stop Kafka (keeps its data)
#
# Don't run `make infra-up` while the root stack's Kafka is up: both bind 9092 and 8090.

SHELL      := /bin/bash
.DEFAULT_GOAL := help

JAR        := target/NotificationService-0.0.1-SNAPSHOT.jar
IMAGE      ?= notification-service
SKIP_TESTS ?= true

# Export .env for one recipe line when present. Sourced by the shell (not `include`) so quoted values work.
WITH_ENV = set -a; [ ! -f ./.env ] || . ./.env; set +a;

.PHONY: help env up down jar run test clean infra-up infra-down infra-reset docker-build docker-run

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

env: ## Create .env from .env.example if it doesn't exist
	@test -f .env || (cp .env.example .env && echo "Created .env - fill in GMAIL_PASSWORD before running.")

up: env infra-up run ## Start Kafka, then build and run the app in the foreground

down: infra-down ## Stop Kafka, keeping its data

jar: ## Build the jar (tests skipped by default; use SKIP_TESTS=false to run them)
	@$(WITH_ENV) ./mvnw clean package -DskipTests=$(SKIP_TESTS)
	@echo "Built $(JAR)"

run: env ## Run the jar with .env loaded (builds it first if missing; SERVER_PORT=9006 make run starts a second instance)
	@test -f $(JAR) || $(MAKE) --no-print-directory jar
	@$(WITH_ENV) java -jar $(JAR)

test: ## Run the tests (Kafka on localhost:9092 is not required)
	@./mvnw test

clean: ## Delete target/
	@./mvnw clean

infra-up: ## Start Kafka (9092, UI on 8090) from docker-compose.yml and wait until healthy
	docker compose up -d --wait

infra-down: ## Stop Kafka, keeping its data
	docker compose down

infra-reset: ## Stop Kafka and delete its data volume
	docker compose down -v

docker-build: ## Build the Docker image (IMAGE=notification-service)
	docker build -t $(IMAGE) .

docker-run: docker-build ## Run the image on :8006 against Kafka and Eureka on the host (GMAIL_PASSWORD from .env or the environment)
	@$(WITH_ENV) docker run --rm -p 8006:8006 -e GMAIL_PASSWORD \
	  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \
	  -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://host.docker.internal:8761/eureka/ $(IMAGE)
