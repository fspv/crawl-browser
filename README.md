# Chrome Crawler Docker Image

A Docker image with Chrome configured for web crawling, including ad blocking, cookie banner bypass. Created initially for my RSS reader to parse article content from my subscriptions. But can be used literally for anything, as it exposes CDP port.

## Features

- Chrome with DevTools Protocol enabled
- Pre-installed extensions:
  - uBlock Origin Lite (ad blocking)
  - I Still Don't Care About Cookies (cookie banner bypass)  
- VNC access for debugging (port 7900)
- Proxy support configured
- Ability to install any other extensions (given the zip archive with the extension)

## Usage

### Running with Docker Compose

Create a `docker-compose.yml` file:

```yaml
services:
  crawl-browser:
    image: nuhotetotniksvoboden/crawl-browser:latest
    ports:
      - "9222:9222"  # Chrome DevTools Protocol
      - "7900:7900"  # noVNC (optional for debugging)
    environment:
      # Optional: Add custom Chrome extensions
      - CHROME_EXTENSIONS=mm|https://github.com/MetaMask/metamask-extension/releases/download/v12.22.3/metamask-flask-chrome-12.22.3-flask.0.zip,justread|https://github.com/ZachSaucier/Just-Read/archive/master.zip|Just-Read-master
```

Then run:
```bash
docker-compose up
```

### CHROME_EXTENSIONS Environment Variable

The `CHROME_EXTENSIONS` variable allows you to install additional Chrome extensions at runtime. The format is:

```
CHROME_EXTENSIONS="alias1|download_url1[|extract_folder1][,alias2|download_url2[|extract_folder2]]"
```

**Parameters:**
- `alias`: Short name for the extension (used in logs)
- `download_url`: Direct download URL for the extension zip file
- `extract_folder`: (Optional) Specific folder name inside the zip file if the extension is not in the root

**Examples:**

1. **MetaMask only:**
   ```yaml
   environment:
     - CHROME_EXTENSIONS=mm|https://github.com/MetaMask/metamask-extension/releases/download/v12.22.3/metamask-flask-chrome-12.22.3-flask.0.zip
   ```

2. **Just-Read only:**
   ```yaml
   environment:
     - CHROME_EXTENSIONS=justread|https://github.com/ZachSaucier/Just-Read/archive/master.zip|Just-Read-master
   ```

3. **Multiple extensions (MetaMask + Just-Read):**
   ```yaml
   environment:
     - CHROME_EXTENSIONS=mm|https://github.com/MetaMask/metamask-extension/releases/download/v12.22.3/metamask-flask-chrome-12.22.3-flask.0.zip,justread|https://github.com/ZachSaucier/Just-Read/archive/master.zip|Just-Read-master
   ```

### Access Points

The Chrome instance is accessible via:
- Chrome DevTools Protocol: port 9222
- VNC viewer: port 7900 (for debugging)

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

