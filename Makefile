.PHONY: build test test-watch test-debug clean help

# Container runtime configuration
# Set CONTAINER_RUNTIME=podman to use podman instead of docker
CONTAINER_RUNTIME ?= docker

# Docker sudo configuration
# Set DOCKER_SUDO=1 to run docker commands with sudo
DOCKER_SUDO ?= 0

ifeq ($(CONTAINER_RUNTIME),podman)
    CONTAINER_CMD := podman
    COMPOSE_CMD := podman-compose --podman-build-args='--format docker'
else
    ifeq ($(DOCKER_SUDO),1)
        CONTAINER_CMD := sudo docker
        COMPOSE_CMD := sudo docker compose
    else
        CONTAINER_CMD := docker
        COMPOSE_CMD := docker compose
    endif
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
	@echo "  DOCKER_SUDO=$(DOCKER_SUDO) (set to '1' to run docker commands with sudo)"
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build with docker (default)"
	@echo "  DOCKER_SUDO=1 make build      # Build with sudo docker"
	@echo "  CONTAINER_RUNTIME=podman make build  # Build with podman"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

info: ## Show current container runtime configuration
	@echo "Current configuration:"
	@echo "  Container runtime: $(CONTAINER_RUNTIME)"
	@echo "  Docker sudo: $(DOCKER_SUDO)"
	@echo "  Container command: $(CONTAINER_CMD)"
	@echo "  Compose command: $(COMPOSE_CMD)"

build: ## Build the main crawler image and test runner image
	@echo "Building main crawler image..."
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):latest .
	@echo "Building test runner image..."
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):test -f tests/Dockerfile.tests ./tests

test: build ## Run all tests
	@echo "Running tests..."
	$(TEST_COMPOSE) up --abort-on-container-exit --build --exit-code-from test-runner
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
	# Clean up regular test containers
	$(TEST_COMPOSE) down -v --remove-orphans || true
	# Clean up all possible test matrix combinations
	@echo "Cleaning up test matrix containers..."
	@for runtime in docker podman; do \
		for proxy in no-proxy with-proxy; do \
			for extensions in default single-extra all-extras; do \
				project="crawl-test-$${runtime}$${proxy}$${extensions}"; \
				if $(COMPOSE_CMD) -p "$$project" ps 2>/dev/null | grep -q "$$project"; then \
					echo "Removing project: $$project"; \
					$(COMPOSE_CMD) -p "$$project" down -v --remove-orphans || true; \
				fi; \
			done; \
		done; \
	done
	# Also clean up any orphaned containers with crawl-test prefix
	@$(CONTAINER_CMD) ps -a --format '{{.Names}}' | grep -E '^crawl-test-' | while read container; do \
		echo "Removing orphaned container: $$container"; \
		$(CONTAINER_CMD) rm -f "$$container" || true; \
	done
	# Remove images
	$(CONTAINER_CMD) rmi $(IMAGE_NAME):latest $(IMAGE_NAME):test 2>/dev/null || true

clean-matrix: ## Clean up only test matrix containers
	@echo "Cleaning up test matrix containers..."
	@for runtime in docker podman; do \
		for proxy in no-proxy with-proxy; do \
			for extensions in default single-extra all-extras; do \
				project="crawl-test-$${runtime}$${proxy}$${extensions}"; \
				echo "Cleaning up project: $$project"; \
				if $(COMPOSE_CMD) -p "$$project" ps 2>/dev/null | grep -q "$$project"; then \
					echo "Removing project: $$project"; \
					$(COMPOSE_CMD) -p "$$project" down -v --remove-orphans || true; \
				fi; \
			done; \
		done; \
	done

logs: ## Show logs from the running services
	$(TEST_COMPOSE) logs -f

shell: build ## Open a shell in the test runner container
	$(TEST_COMPOSE) up -d crawl-browser
	$(TEST_COMPOSE) run --rm test-runner /bin/bash
	$(TEST_COMPOSE) down

# Test Matrix targets
test-matrix: ## Run all test matrix combinations
	@echo "Running full test matrix..."
	./test-matrix.sh

test-matrix-docker: ## Run all Docker test combinations
	@echo "Running Docker test matrix..."
	./test-matrix.sh --runtime docker

test-matrix-podman: ## Run all Podman test combinations
	@echo "Running Podman test matrix..."
	./test-matrix.sh --runtime podman

test-matrix-proxy: ## Run all proxy test combinations
	@echo "Running proxy test matrix..."
	./test-matrix.sh --proxy with-proxy

test-matrix-extensions: ## Run all extension test combinations
	@echo "Running extension test matrix..."
	./test-matrix.sh --extensions all-extras

test-docker-proxy: ## Test Docker with proxy
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):latest .
	$(COMPOSE_CMD) \
		-f docker-compose/base.yml \
		-f docker-compose/runtime/docker.yml \
		-f docker-compose/proxy/with-proxy.yml \
		-f docker-compose/extensions/default.yml \
		up --abort-on-container-exit --exit-code-from test-runner

test-podman-extensions: ## Test Podman with all extensions
	$(CONTAINER_CMD) build -t $(IMAGE_NAME):latest .
	podman-compose \
		-f docker-compose/base.yml \
		-f docker-compose/runtime/podman.yml \
		-f docker-compose/proxy/no-proxy.yml \
		-f docker-compose/extensions/all-extras.yml \
		up --abort-on-container-exit --exit-code-from test-runner
