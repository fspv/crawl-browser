.PHONY: build test test-watch test-debug clean help

# Container runtime configuration
# Set CONTAINER_RUNTIME=podman to use podman instead of docker
CONTAINER_RUNTIME ?= docker
ifeq ($(CONTAINER_RUNTIME),podman)
    CONTAINER_CMD := podman
    COMPOSE_CMD := podman-compose
else
    CONTAINER_CMD := docker
    COMPOSE_CMD := docker compose
endif

# Variables
IMAGE_NAME := crawl-browser
TEST_COMPOSE := $(COMPOSE_CMD) -f docker-compose.test.yml
DOCKER_BUILDKIT := 1

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Configuration:"
	@echo "  CONTAINER_RUNTIME=$(CONTAINER_RUNTIME) (set to 'podman' to use podman instead of docker)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build with docker (default)"
	@echo "  CONTAINER_RUNTIME=podman make build  # Build with podman"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

info: ## Show current container runtime configuration
	@echo "Current configuration:"
	@echo "  Container runtime: $(CONTAINER_RUNTIME)"
	@echo "  Container command: $(CONTAINER_CMD)"
	@echo "  Compose command: $(COMPOSE_CMD)"

build: ## Build the main crawler image and test runner image
	@echo "Building main crawler image..."
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):latest .
	@echo "Building test runner image..."
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):test -f tests/Dockerfile.tests ./tests

test: build ## Run all tests
	@echo "Running tests..."
	$(TEST_COMPOSE) up --abort-on-container-exit --exit-code-from test-runner
	$(TEST_COMPOSE) down

test-watch: build ## Run tests in watch mode (for development)
	@echo "Starting crawler service..."
	$(TEST_COMPOSE) up -d crawl-browser
	@echo "Running tests in watch mode..."
	$(TEST_COMPOSE) run --rm test-runner npm run test:watch
	$(TEST_COMPOSE) down

test-debug: build ## Run tests with VNC access for debugging
	@echo "Starting crawler service with VNC..."
	$(TEST_COMPOSE) up -d crawl-browser
	@echo ""
	@echo "========================================="
	@echo "VNC available at: http://localhost:7900"
	@echo "CDP available at: http://localhost:9222"
	@echo "========================================="
	@echo ""
	$(TEST_COMPOSE) run --rm test-runner npm run test:debug
	$(TEST_COMPOSE) down

test-specific: build ## Run specific test file or pattern (use TEST=<pattern>)
	@if [ -z "$(TEST)" ]; then \
		echo "Error: TEST variable not set. Usage: make test-specific TEST=<pattern>"; \
		exit 1; \
	fi
	$(TEST_COMPOSE) up -d crawl-browser
	$(TEST_COMPOSE) run --rm test-runner npm test -- --grep "$(TEST)"
	$(TEST_COMPOSE) down

clean: ## Clean up containers, images, and test results
	@echo "Cleaning up..."
	$(TEST_COMPOSE) down -v --remove-orphans
	$(CONTAINER_CMD) rmi $(IMAGE_NAME):latest $(IMAGE_NAME):test 2>/dev/null || true
	rm -rf test-results/*

logs: ## Show logs from the running services
	$(TEST_COMPOSE) logs -f

shell: build ## Open a shell in the test runner container
	$(TEST_COMPOSE) up -d crawl-browser
	$(TEST_COMPOSE) run --rm test-runner /bin/bash
	$(TEST_COMPOSE) down
