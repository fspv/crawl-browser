.PHONY: test test-watch test-debug clean help

# Docker sudo configuration
# Set DOCKER_SUDO=1 to run docker commands with sudo
DOCKER_SUDO ?= 0

ifeq ($(DOCKER_SUDO),1)
	COMPOSE_CMD := sudo docker compose
else
	COMPOSE_CMD := docker compose
endif

# Default target
.DEFAULT_GOAL := info

info: ## Show current container runtime configuration
	@echo "Current configuration:"
	@echo "  Docker sudo: $(DOCKER_SUDO)"
	@echo "  Compose command: $(COMPOSE_CMD)"

# Test matrix targets - Docker configurations
test-docker-no-proxy-default: ## Test Docker with no proxy and default extensions
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_default.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_default.yml down

test-docker-no-proxy-single-extra: ## Test Docker with no proxy and single extra extension
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_single_extra.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_single_extra.yml down

test-docker-no-proxy-all-extras: ## Test Docker with no proxy and all extra extensions
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_all_extras.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_all_extras.yml down

test-docker-with-proxy-default: ## Test Docker with proxy and default extensions
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_default.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_default.yml down

test-docker-with-proxy-single-extra: ## Test Docker with proxy and single extra extension
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_single_extra.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_single_extra.yml down

test-docker-with-proxy-all-extras: ## Test Docker with proxy and all extra extensions
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_all_extras.yml up --abort-on-container-exit --exit-code-from test-runner --build
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_all_extras.yml down

# Test matrix targets - Podman configurations
test-podman-no-proxy-default: ## Test Podman with no proxy and default extensions
	podman-compose -f docker-compose.test_podman_no_proxy_default.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_no_proxy_default.yml down

test-podman-no-proxy-single-extra: ## Test Podman with no proxy and single extra extension
	podman-compose -f docker-compose.test_podman_no_proxy_single_extra.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_no_proxy_single_extra.yml down

test-podman-no-proxy-all-extras: ## Test Podman with no proxy and all extra extensions
	podman-compose -f docker-compose.test_podman_no_proxy_all_extras.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_no_proxy_all_extras.yml down

test-podman-with-proxy-default: ## Test Podman with proxy and default extensions
	podman-compose -f docker-compose.test_podman_with_proxy_default.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_with_proxy_default.yml down

test-podman-with-proxy-single-extra: ## Test Podman with proxy and single extra extension
	podman-compose -f docker-compose.test_podman_with_proxy_single_extra.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_with_proxy_single_extra.yml down

test-podman-with-proxy-all-extras: ## Test Podman with proxy and all extra extensions
	podman-compose -f docker-compose.test_podman_with_proxy_all_extras.yml up --abort-on-container-exit --exit-code-from test-runner --build
	podman-compose -f docker-compose.test_podman_with_proxy_all_extras.yml down

# Convenience targets
test: test-docker-no-proxy-default ## Run default test (docker, no proxy, default extensions)

test-all-docker: ## Run all Docker test configurations
	$(MAKE) test-docker-no-proxy-default
	$(MAKE) test-docker-no-proxy-single-extra
	$(MAKE) test-docker-no-proxy-all-extras
	$(MAKE) test-docker-with-proxy-default
	$(MAKE) test-docker-with-proxy-single-extra
	$(MAKE) test-docker-with-proxy-all-extras

test-all-podman: ## Run all Podman test configurations
	$(MAKE) test-podman-no-proxy-default
	$(MAKE) test-podman-no-proxy-single-extra
	$(MAKE) test-podman-no-proxy-all-extras
	$(MAKE) test-podman-with-proxy-default
	$(MAKE) test-podman-with-proxy-single-extra
	$(MAKE) test-podman-with-proxy-all-extras

test-all: ## Run all test configurations
	$(MAKE) test-all-docker
	$(MAKE) test-all-podman

clean: ## Clean up containers, images, and test results
	@echo "Cleaning up..."
	# Clean up Docker test configurations
	@echo "Cleaning up Docker configurations..."
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_default.yml down -v --remove-orphans || true
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_single_extra.yml down -v --remove-orphans || true
	$(COMPOSE_CMD) -f docker-compose.test_docker_no_proxy_all_extras.yml down -v --remove-orphans || true
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_default.yml down -v --remove-orphans || true
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_single_extra.yml down -v --remove-orphans || true
	$(COMPOSE_CMD) -f docker-compose.test_docker_with_proxy_all_extras.yml down -v --remove-orphans || true
	# Clean up Podman test configurations
	podman-compose -f docker-compose.test_podman_no_proxy_default.yml down -v --remove-orphans || true; \
	podman-compose -f docker-compose.test_podman_no_proxy_single_extra.yml down -v --remove-orphans || true; \
	podman-compose -f docker-compose.test_podman_no_proxy_all_extras.yml down -v --remove-orphans || true; \
	podman-compose -f docker-compose.test_podman_with_proxy_default.yml down -v --remove-orphans || true; \
	podman-compose -f docker-compose.test_podman_with_proxy_single_extra.yml down -v --remove-orphans || true; \
	podman-compose -f docker-compose.test_podman_with_proxy_all_extras.yml down -v --remove-orphans || true; \
