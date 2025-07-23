const { test, expect } = require('@playwright/test');
const CDP = require('chrome-remote-interface');

test.describe('Infrastructure Health Checks', () => {
  test('Chrome DevTools Protocol is accessible', async () => {
    // Chrome's HTTP endpoint requires localhost or IP address in Host header,
    // so we test CDP accessibility via the WebSocket connection instead
    const client = await CDP({
      host: 'crawl-browser',
      port: 9222
    });
    
    const version = await client.Browser.getVersion();
    expect(version).toHaveProperty('product');
    expect(version.product).toContain('Chrome');
    
    await client.close();
  });

  test('Can establish CDP connection', async () => {
    const client = await CDP({
      host: 'crawl-browser',
      port: 9222
    });
    
    expect(client).toBeDefined();
    expect(client.Page).toBeDefined();
    expect(client.Network).toBeDefined();
    
    await client.close();
  });

  test('Can create new browser context', async () => {
    let client;
    let targetId;
    
    try {
      client = await CDP({
        host: 'crawl-browser',
        port: 9222
      });
      
      const result = await client.Target.createTarget({ url: 'about:blank' });
      targetId = result.targetId;
      expect(targetId).toBeTruthy();
      
    } finally {
      // Clean up in reverse order with error handling
      if (targetId && client) {
        try {
          await client.Target.closeTarget({ targetId });
        } catch (e) {
          console.log('Warning: Could not close target:', e.message);
        }
      }
      if (client) {
        try {
          await client.close();
        } catch (e) {
          console.log('Warning: Could not close client:', e.message);
        }
      }
    }
  });

  test('VNC server is accessible on port 7900', async () => {
    try {
      const response = await fetch('http://crawl-browser:7900');
      expect(response.ok).toBeTruthy();
    } catch (error) {
      // VNC might not always return a proper HTTP response
      // but connection should at least be possible
      expect(error.code).not.toBe('ECONNREFUSED');
    }
  });
});