# Chrome Crawler Docker Image

A Docker image with Chrome configured for web crawling, including ad blocking, cookie banner bypass.

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
```

### Local Development

1. Build the image: `make build`
2. Run tests: `make test`
3. Debug with VNC: `make test-debug` then open http://localhost:7900

## Usage

The Chrome instance is accessible via:
- Chrome DevTools Protocol: port 9222
- VNC viewer: port 7900 (for debugging)
