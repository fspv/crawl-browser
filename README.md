# Chrome Crawler Docker Image

A Docker image with Chrome configured for web crawling, including ad blocking, cookie banner bypass, and paywall circumvention.

## Features

- Chrome with DevTools Protocol enabled
- Pre-installed extensions:
  - uBlock Origin Lite (ad blocking)
  - I Still Don't Care About Cookies (cookie banner bypass)  
  - Bypass Paywalls Clean
- VNC access for debugging (port 7900)
- Proxy support configured

## Testing

This project includes a comprehensive test suite using Playwright and Chrome DevTools Protocol.

### Running Tests

```bash
# Run all tests
make test

# Run tests in watch mode (for development)
make test-watch

# Run tests with VNC debugging access
make test-debug

# Run specific test suite
make test-specific TEST="infrastructure"

# View help
make help
```

### Test Structure

- `tests/infrastructure/` - Tests for Docker container health, Chrome configuration
- `tests/content/` - Tests for page navigation, content extraction, error handling
- `tests/extensions/` - Tests for extension loading and functionality
- `tests/utils/` - Helper utilities for testing

### CI/CD

Tests run automatically on push/PR via GitHub Actions. Test results and screenshots are uploaded as artifacts.

### Local Development

1. Build the image: `make build`
2. Run tests: `make test`
3. Debug with VNC: `make test-debug` then open http://localhost:7900

## Usage

The Chrome instance is accessible via:
- Chrome DevTools Protocol: port 9222
- VNC viewer: port 7900 (for debugging)