# Test Matrix Configuration

This directory contains modular Docker Compose configurations for testing the crawl-browser under different conditions.

## Structure

```
docker-compose/
├── base.yml                    # Base configuration shared by all tests
├── runtime/
│   ├── docker.yml             # Docker-specific settings (privileged: true)
│   └── podman.yml             # Podman-specific settings
├── proxy/
│   ├── no-proxy.yml           # No proxy configuration
│   └── with-proxy.yml         # HTTP proxy configuration
├── extensions/
│   ├── default.yml            # Default extensions only
│   ├── single-extra.yml       # Default + MetaMask
│   └── all-extras.yml         # Default + all extra extensions
└── services/
    └── squid.conf             # Proxy server configuration
```

## Test Matrix

The test matrix covers:
- **2 Container Runtimes**: Docker, Podman
- **2 Proxy Configurations**: No proxy, HTTP proxy
- **3 Extension Configurations**: Default only, Single extra, All extras

Total: 12 test combinations

## Usage

### Run Full Test Matrix
```bash
make test-matrix
# or
./test-matrix.sh

# With sudo for Docker
DOCKER_SUDO=1 make test-matrix
```

### Run Specific Configurations
```bash
# Test only Docker runtime
make test-matrix-docker

# Test only proxy configurations
make test-matrix-proxy

# Test specific combination
docker-compose \
  -f docker-compose/base.yml \
  -f docker-compose/runtime/docker.yml \
  -f docker-compose/proxy/with-proxy.yml \
  -f docker-compose/extensions/single-extra.yml \
  up --abort-on-container-exit --exit-code-from test-runner
```

### Filter Test Matrix
```bash
# Run tests for specific runtime
./test-matrix.sh --runtime docker

# Run tests for specific proxy config
./test-matrix.sh --proxy with-proxy

# Run tests for specific extension config
./test-matrix.sh --extensions all-extras

# Combine filters
./test-matrix.sh --runtime podman --proxy with-proxy
```

## GitHub Actions

The test matrix runs automatically in GitHub Actions:
- On push to main/master/develop branches
- On pull requests
- Manual trigger with optional filters

View the workflow: `.github/workflows/test-matrix.yml`

## Adding New Test Dimensions

To add a new test dimension:

1. Create a new subdirectory (e.g., `docker-compose/feature/`)
2. Add configuration files for each variant
3. Update the test matrix script to include the new dimension
4. Update GitHub Actions workflow matrix

## Notes

- Docker tests run with `privileged: true` for compatibility
- Podman tests run without privileged mode
- Proxy tests use Squid proxy without authentication
- Test results are saved in `test-results/matrix/<test-name>/`