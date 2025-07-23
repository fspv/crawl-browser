const { test, expect } = require('@playwright/test');
const CDP = require('chrome-remote-interface');

test.describe('Page Navigation and Content Extraction', () => {
  let client;
  let target;

  test.beforeEach(async () => {
    client = await CDP({
      host: 'crawl-browser',
      port: 9222
    });
    
    const { targetId } = await client.Target.createTarget({ url: 'about:blank' });
    target = targetId;
    
    await client.Page.enable();
    await client.Network.enable();
    await client.Runtime.enable();
  });

  test.afterEach(async () => {
    if (target) {
      await client.Target.closeTarget({ targetId: target });
    }
    if (client) {
      await client.close();
    }
  });

  test('Can navigate to pages and extract content', async () => {
    await client.Page.navigate({ url: 'https://httpbin.org/html' });
    
    await client.Page.loadEventFired();
    
    // Wait a bit more for content to be ready
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Debug what we actually have on the page
    try {
      const { result: debugResult } = await client.Runtime.evaluate({
        expression: 'document.title || "no title"'
      });
      console.log('Title result:', JSON.stringify(debugResult, null, 2));
      
      const { result: urlResult } = await client.Runtime.evaluate({
        expression: 'document.location.href'
      });
      console.log('URL result:', JSON.stringify(urlResult, null, 2));
      
      // Just verify we can evaluate JavaScript on the page
      expect(urlResult.value).toContain('httpbin.org');
    } catch (error) {
      console.log('Runtime evaluation failed:', error.message);
      throw error;
    }
    
    // Extract main content
    const { result: contentResult } = await client.Runtime.evaluate({
      expression: 'document.querySelector("h1").textContent'
    });
    expect(contentResult.value).toBe('Herman Melville - Moby-Dick');
  });

  test('Can handle JavaScript-rendered content', async () => {
    // Navigate to a page that uses JavaScript
    await client.Page.navigate({ url: 'https://httpbin.org/html' });
    
    // Wait for any dynamic content
    await client.Page.loadEventFired();
    
    // Inject and execute JavaScript
    const { result } = await client.Runtime.evaluate({
      expression: `
        // Simulate dynamic content injection
        const div = document.createElement('div');
        div.id = 'dynamic-content';
        div.textContent = 'Dynamically added';
        document.body.appendChild(div);
        document.getElementById('dynamic-content').textContent;
      `
    });
    
    expect(result.value).toBe('Dynamically added');
  });

  test('Can intercept network requests', async () => {
    const requests = [];
    
    client.Network.requestWillBeSent((params) => {
      requests.push(params.request.url);
    });
    
    await client.Page.navigate({ url: 'https://httpbin.org/html' });
    
    await client.Page.loadEventFired();
    
    // Should have captured the main request
    expect(requests).toContain('https://httpbin.org/html');
    expect(requests.length).toBeGreaterThan(0);
  });

  test('Can extract clean article content', async () => {
    // This is a simplified test - in real scenario you'd test against
    // actual article pages with ads, sidebars, etc.
    
    await client.Page.navigate({ url: 'https://httpbin.org/html' });
    
    await client.Page.loadEventFired();
    
    // Simulate article extraction logic
    const { result } = await client.Runtime.evaluate({
      expression: `
        // Get main content area (simplified)
        const content = document.querySelector('body').innerText;
        // Remove extra whitespace
        content.trim().replace(/\\s+/g, ' ');
      `
    });
    
    expect(result.value).toBeTruthy();
    expect(result.value.length).toBeGreaterThan(10);
  });
});
